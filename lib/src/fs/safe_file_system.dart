import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;

import '../core/exceptions.dart';
import '../naming/name_converter.dart';
import 'write_plan.dart';

/// Safe, project-rooted filesystem operations for generators.
///
/// Multi-file batches validate paths first, stage content to temps, then
/// commit. If a later commit fails, previously committed files in the same
/// batch are rolled back (restored from backup or deleted if newly created).
///
/// Limitations: rollback is best-effort on Windows (antivirus/locks may block
/// restores). Cross-process atomicity is not guaranteed.
final class SafeFileSystem {
  SafeFileSystem({
    required this.projectRoot,
    this.createBackups = true,
    this.failAfterCommits,
  }) : _root = p.normalize(p.absolute(projectRoot));

  final String projectRoot;
  final bool createBackups;
  final String _root;

  /// Test hook: throw after successfully committing this many writes.
  final int? failAfterCommits;

  String get root => _root;

  /// Resolves [relativePath] under the project root with traversal protection.
  String resolvePath(String relativePath) {
    final normalizedRelative = p.normalize(relativePath.replaceAll('\\', '/'));
    if (p.isAbsolute(normalizedRelative)) {
      throw InvalidUsageException(
        'Absolute paths are not allowed: $relativePath',
      );
    }

    final segments = p.posix.split(normalizedRelative.replaceAll('\\', '/'));
    for (final segment in segments) {
      if (segment == '..') {
        throw InvalidUsageException(
          'Path traversal is not allowed: $relativePath',
        );
      }
      if (segment != '.' && segment.isNotEmpty) {
        NameConverter.validatePathSegment(segment);
      }
    }

    final absolute = p.normalize(p.join(_root, normalizedRelative));
    final rootWithSep = _root.endsWith(p.separator)
        ? _root
        : '$_root${p.separator}';
    if (absolute != _root && !absolute.startsWith(rootWithSep)) {
      throw InvalidUsageException(
        'Resolved path escapes project root: $relativePath',
      );
    }
    return absolute;
  }

  /// Applies [writes] under the project root with staged commit + rollback.
  Future<WritePlanResult> applyWrites(
    List<PlannedFileWrite> writes, {
    bool dryRun = false,
    bool force = false,
  }) async {
    final prepared = <_PreparedWrite>[];
    for (final write in writes) {
      final absolute = resolvePath(write.relativePath);
      final file = File(absolute);
      final exists = file.existsSync();

      var mode = write.mode;
      if (force && mode == FileWriteMode.create) {
        mode = FileWriteMode.overwrite;
      }

      if (exists && mode == FileWriteMode.create) {
        throw ExecutionException(
          'Refusing to overwrite existing file.',
          details: absolute,
        );
      }

      prepared.add(
        _PreparedWrite(
          write: write,
          absolutePath: absolute,
          existed: exists,
          mode: mode,
        ),
      );
    }

    if (dryRun) {
      return WritePlanResult(
        results: [
          for (final item in prepared)
            FileWriteResult(
              relativePath: item.write.relativePath,
              absolutePath: item.absolutePath,
              outcome: item.existed && item.mode == FileWriteMode.skipIfExists
                  ? FileWriteOutcome.skippedExists
                  : FileWriteOutcome.dryRun,
            ),
        ],
        dryRun: true,
      );
    }

    // Stage all contents to temp files first.
    final staged = <_StagedWrite>[];
    try {
      for (final item in prepared) {
        if (item.existed && item.mode == FileWriteMode.skipIfExists) {
          staged.add(
            _StagedWrite(
              prepared: item,
              tempPath: null,
              backupPath: null,
              skip: true,
            ),
          );
          continue;
        }

        String? backupPath;
        if (item.existed &&
            item.mode == FileWriteMode.overwrite &&
            createBackups) {
          backupPath = await _backup(File(item.absolutePath));
        }

        final tempPath = await _stageTemp(
          File(item.absolutePath),
          item.write.content,
        );
        staged.add(
          _StagedWrite(
            prepared: item,
            tempPath: tempPath,
            backupPath: backupPath,
            skip: false,
          ),
        );
      }
    } catch (error) {
      await _cleanupTemps(staged);
      if (error is DevKitException) rethrow;
      throw ExecutionException(
        'Failed to stage generation writes.',
        cause: error,
      );
    }

    final results = <FileWriteResult>[];
    final committed = <_CommittedWrite>[];
    try {
      for (final item in staged) {
        if (item.skip) {
          results.add(
            FileWriteResult(
              relativePath: item.prepared.write.relativePath,
              absolutePath: item.prepared.absolutePath,
              outcome: FileWriteOutcome.skippedExists,
            ),
          );
          continue;
        }

        final file = File(item.prepared.absolutePath);
        await file.parent.create(recursive: true);
        if (file.existsSync()) {
          await file.delete();
        }
        await File(item.tempPath!).rename(file.path);
        item.tempPath = null;

        final outcome = !item.prepared.existed
            ? FileWriteOutcome.created
            : item.backupPath != null
            ? FileWriteOutcome.backedUpAndOverwritten
            : FileWriteOutcome.overwritten;

        final committedWrite = _CommittedWrite(
          absolutePath: item.prepared.absolutePath,
          relativePath: item.prepared.write.relativePath,
          createdNew: !item.prepared.existed,
          backupPath: item.backupPath,
        );
        committed.add(committedWrite);
        results.add(
          FileWriteResult(
            relativePath: item.prepared.write.relativePath,
            absolutePath: item.prepared.absolutePath,
            outcome: outcome,
            backupPath: item.backupPath,
          ),
        );

        if (failAfterCommits != null && committed.length >= failAfterCommits!) {
          throw const ExecutionException(
            'Injected write failure for rollback testing.',
          );
        }
      }
    } catch (error) {
      final rollbackErrors = await _rollback(committed);
      await _cleanupTemps(staged);
      final details = StringBuffer()
        ..writeln(error is DevKitException ? error.message : error.toString());
      if (rollbackErrors.isNotEmpty) {
        details
          ..writeln('Rollback issues:')
          ..writeln(rollbackErrors.map((e) => '  - $e').join('\n'));
      } else if (committed.isNotEmpty) {
        details.writeln(
          'Rolled back ${committed.length} committed file(s) from this batch.',
        );
      }
      throw ExecutionException(
        'Generation batch failed; attempted rollback.',
        details: details.toString().trim(),
        cause: error,
      );
    }

    return WritePlanResult(results: results, dryRun: false);
  }

  Future<void> ensureDirectory(String relativePath) async {
    final absolute = resolvePath(relativePath);
    final dir = Directory(absolute);
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
  }

  Future<String> _backup(File file) async {
    final stamp = DateTime.now().toUtc().millisecondsSinceEpoch;
    final backupPath = '${file.path}.bak.$stamp';
    await file.copy(backupPath);
    return backupPath;
  }

  Future<String> _stageTemp(File target, String content) async {
    await target.parent.create(recursive: true);
    final tempName =
        '.${p.basename(target.path)}.${Random().nextInt(1 << 32)}.tmp';
    final tempFile = File(p.join(target.parent.path, tempName));
    await tempFile.writeAsString(content);
    return tempFile.path;
  }

  Future<void> _cleanupTemps(List<_StagedWrite> staged) async {
    for (final item in staged) {
      final temp = item.tempPath;
      if (temp == null) continue;
      final file = File(temp);
      if (file.existsSync()) {
        try {
          await file.delete();
        } catch (_) {}
      }
      item.tempPath = null;
    }
  }

  Future<List<String>> _rollback(List<_CommittedWrite> committed) async {
    final errors = <String>[];
    for (final item in committed.reversed) {
      try {
        final file = File(item.absolutePath);
        if (item.createdNew) {
          if (file.existsSync()) await file.delete();
        } else if (item.backupPath != null) {
          final backup = File(item.backupPath!);
          if (backup.existsSync()) {
            await file.parent.create(recursive: true);
            if (file.existsSync()) await file.delete();
            await backup.copy(file.path);
            await backup.delete();
          }
        }
      } catch (error) {
        errors.add('${item.relativePath}: $error');
      }
    }
    return errors;
  }
}

final class _PreparedWrite {
  const _PreparedWrite({
    required this.write,
    required this.absolutePath,
    required this.existed,
    required this.mode,
  });

  final PlannedFileWrite write;
  final String absolutePath;
  final bool existed;
  final FileWriteMode mode;
}

final class _StagedWrite {
  _StagedWrite({
    required this.prepared,
    required this.tempPath,
    required this.backupPath,
    required this.skip,
  });

  final _PreparedWrite prepared;
  String? tempPath;
  final String? backupPath;
  final bool skip;
}

final class _CommittedWrite {
  const _CommittedWrite({
    required this.absolutePath,
    required this.relativePath,
    required this.createdNew,
    required this.backupPath,
  });

  final String absolutePath;
  final String relativePath;
  final bool createdNew;
  final String? backupPath;
}
