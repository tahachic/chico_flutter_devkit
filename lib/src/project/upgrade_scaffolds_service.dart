import 'dart:io';

import 'package:path/path.dart' as p;

import '../core/exceptions.dart';
import '../fs/custom_regions.dart';
import '../generators/feature/feature_integration.dart';
import 'generate_manifest.dart';

/// Result of `devkit upgrade scaffolds`.
final class UpgradeScaffoldsResult {
  const UpgradeScaffoldsResult({
    required this.dryRun,
    required this.refreshed,
    required this.skippedDrift,
    required this.message,
  });

  final bool dryRun;
  final List<String> refreshed;
  final List<String> skippedDrift;
  final String message;
}

/// Refreshes DevKit anchor stubs safely (manifest + custom-region aware).
final class UpgradeScaffoldsService {
  Future<UpgradeScaffoldsResult> run({
    required String projectRoot,
    bool dryRun = false,
    bool force = false,
  }) async {
    final root = p.normalize(projectRoot);
    final manifest = GenerateManifest.load(root);
    final refreshed = <String>[];
    final skipped = <String>[];

    // 1) Ensure core anchor files keep DevKit markers (create if missing).
    for (final entry in _anchorTemplates.entries) {
      final relative = entry.key;
      final absolute = p.join(root, relative);
      final file = File(absolute);
      if (!file.existsSync()) {
        if (!dryRun) {
          await file.parent.create(recursive: true);
          await file.writeAsString(entry.value);
        }
        refreshed.add(relative);
        continue;
      }
      final current = file.readAsStringSync();
      final required = entry.value;
      // Only refresh when file is still a stub (contains markers, no extra
      // registrations beyond empty regions) OR force.
      if (_isBlankAnchorFile(current, relative) || force) {
        if (!CustomRegions.onlyCustomRegionsDiffer(
              previous: current,
              generated: required,
            ) &&
            current != required &&
            !force &&
            manifest[relative] != null &&
            !manifest.isUnchanged(relative)) {
          skipped.add(relative);
          continue;
        }
        if (!dryRun) {
          final merged = CustomRegions.merge(
            generated: required,
            previous: current,
          );
          await file.writeAsString(merged);
        }
        refreshed.add(relative);
      }
    }

    // 2) Manifest-tracked files: refuse outside-region drift unless --force.
    for (final path in manifest.entries.keys) {
      if (!manifest.isUnchanged(path)) {
        final file = File(p.join(root, path));
        if (!file.existsSync()) continue;
        final onDisk = file.readAsStringSync();
        // Without regenerated content we cannot auto-fix arbitrary gens;
        // surface drift for doctor / --sync workflows.
        if (CustomRegions.extract(onDisk).isNotEmpty) {
          // Region-bearing files: user should re-run generate --sync.
          skipped.add(path);
        } else if (!force) {
          skipped.add(path);
        }
      }
    }

    final message = StringBuffer()
      ..writeln(
        dryRun
            ? 'Dry-run: would refresh ${refreshed.length} scaffold file(s).'
            : 'Refreshed ${refreshed.length} scaffold file(s).',
      );
    if (refreshed.isNotEmpty) {
      message.writeln('  ${refreshed.join(', ')}');
    }
    if (skipped.isNotEmpty) {
      message
        ..writeln(
          'Skipped ${skipped.length} drifted file(s) '
          '(use generate … --sync or --force):',
        )
        ..writeln('  ${skipped.toSet().join(', ')}');
    }

    if (!Directory(p.join(root, '.chico')).existsSync() &&
        refreshed.isEmpty &&
        skipped.isEmpty) {
      throw const InvalidUsageException(
        'No DevKit project markers found.',
        details: 'Run `devkit adopt` or `devkit create` first.',
      );
    }

    return UpgradeScaffoldsResult(
      dryRun: dryRun,
      refreshed: refreshed,
      skippedDrift: skipped.toSet().toList(growable: false),
      message: message.toString().trimRight(),
    );
  }

  bool _isBlankAnchorFile(String source, String relative) {
    if (relative.endsWith('feature_routes.dart')) {
      return source.contains(FeatureIntegration.routesBegin) &&
          !RegExp(r'GoRoute\(|Navigator\.|path:').hasMatch(
            source
                .split(FeatureIntegration.routesBegin)
                .last
                .split(FeatureIntegration.routesEnd)
                .first,
          );
    }
    if (relative.endsWith('feature_registrations.dart')) {
      return source.contains(FeatureIntegration.regsBegin);
    }
    return false;
  }

  static final Map<String, String> _anchorTemplates = {
    FeatureIntegration.featureRoutesPath:
        '''
import 'package:go_router/go_router.dart';

${FeatureIntegration.routeImportsBegin}
${FeatureIntegration.routeImportsEnd}

/// GoRoutes appended by `devkit generate feature`.
List<RouteBase> get featureRoutes => [
  ${FeatureIntegration.routesBegin}
  ${FeatureIntegration.routesEnd}
];
''',
    FeatureIntegration.featureRegistrationsPath:
        '''
import 'package:get_it/get_it.dart';

${FeatureIntegration.diImportsBegin}
${FeatureIntegration.diImportsEnd}

/// Feature DI registrations appended by `devkit generate feature`.
void registerFeatures(GetIt getIt) {
  ${FeatureIntegration.regsBegin}
  ${FeatureIntegration.regsEnd}
}
''',
  };
}
