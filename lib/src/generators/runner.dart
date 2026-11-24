import 'dart:io';

import 'package:path/path.dart' as p;

import '../config/config_service.dart';
import '../config/overrides.dart';
import '../core/exceptions.dart';
import '../fs/custom_regions.dart';
import '../fs/write_plan.dart';
import '../project/generate_manifest.dart';
import '../template/catalog.dart';
import 'context.dart';
import 'generator.dart';
import 'registry.dart';
import 'result.dart';

/// Orchestrates config resolution → validate → generate.
final class GeneratorRunner {
  GeneratorRunner({
    required this.registry,
    required this.configService,
    this.templateCatalog,
    this.contextFactory = const GenerationContextFactory(),
  });

  final GeneratorRegistry registry;
  final ConfigService configService;
  final TemplateCatalog? templateCatalog;
  final GenerationContextFactory contextFactory;

  Future<GenerationResult> run({
    required String projectRoot,
    required String generatorName,
    required String targetName,
    ConfigOverrides overrides = const ConfigOverrides(),
    bool dryRun = false,
    bool force = false,
    bool sync = false,
    Map<String, Object?> extra = const {},
  }) async {
    final generator = registry.get(generatorName);
    final resolved = configService.resolve(
      projectRoot: projectRoot,
      overrides: overrides,
    );

    final context = contextFactory.create(
      resolved: resolved,
      name: targetName,
      dryRun: dryRun,
      force: force,
      sync: sync,
      extra: extra,
      templateCatalog: templateCatalog,
    );

    await generator.validate(context);
    return generator.generate(context);
  }
}

/// Optional base class that applies planned writes through [SafeFileSystem].
abstract class BaseGenerator implements Generator {
  Future<GenerationResult> commitWrites({
    required GenerationContext context,
    required List<PlannedFileWrite> writes,
    String? message,
  }) async {
    final manifest = GenerateManifest.load(context.projectRoot);
    final effective = <PlannedFileWrite>[];

    for (final write in writes) {
      final absolute = context.fileSystem.resolvePath(write.relativePath);
      final file = File(absolute);
      final exists = file.existsSync();
      var mode = write.mode;
      var content = write.content;
      final previous = exists ? file.readAsStringSync() : null;

      if (context.force && mode == FileWriteMode.create) {
        mode = FileWriteMode.overwrite;
      } else if (context.sync && exists && mode == FileWriteMode.create) {
        if (manifest.isUnchanged(write.relativePath)) {
          mode = FileWriteMode.overwrite;
        } else if (manifest[write.relativePath] != null &&
            previous != null &&
            CustomRegions.onlyCustomRegionsDiffer(
              previous: previous,
              generated: write.content,
            )) {
          // User only edited inside custom regions — safe to sync + reinject.
          mode = FileWriteMode.overwrite;
        } else if (manifest[write.relativePath] != null) {
          throw ExecutionException(
            'Refusing to sync user-edited generated file.',
            details:
                '${p.normalize(absolute)}\n'
                'Use --force to overwrite, or restore the file before --sync.',
          );
        }
      }

      if (previous != null &&
          (mode == FileWriteMode.overwrite || context.force || context.sync) &&
          CustomRegions.extract(write.content).isNotEmpty) {
        content = CustomRegions.merge(
          generated: write.content,
          previous: previous,
        );
      }

      effective.add(
        PlannedFileWrite(
          relativePath: write.relativePath,
          content: content,
          mode: mode,
        ),
      );
    }

    final result = await context.fileSystem.applyWrites(
      effective,
      dryRun: context.dryRun,
      force: context.force,
    );

    if (!context.dryRun) {
      for (final write in effective) {
        final matches = result.results
            .where((r) => r.relativePath == write.relativePath)
            .toList(growable: false);
        if (matches.isEmpty) continue;
        final outcome = matches.first.outcome;
        if (outcome == FileWriteOutcome.skippedExists) continue;
        if (outcome == FileWriteOutcome.dryRun) continue;
        manifest.upsert(
          relativePath: write.relativePath,
          generator: name,
          content: write.content,
        );
      }
      await manifest.save();
    }

    return GenerationResult(
      generatorName: name,
      writes: result,
      message: message,
    );
  }
}
