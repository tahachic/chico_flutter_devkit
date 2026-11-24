import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import '../config/config_paths.dart';
import '../config/config_service.dart';
import '../config/defaults.dart';
import '../core/exceptions.dart';
import '../integrations/chico/chico_packages.dart';
import '../project/generate_manifest.dart';
import '../pubspec/pubspec_editor.dart';
import '../quality/tool_runner.dart';
import 'models.dart';

/// Diagnoses a Flutter project and applies only safe fixes.
final class DoctorService {
  DoctorService({required this.configService, required this.toolRunner});

  final ConfigService configService;
  final ToolRunner toolRunner;

  static const int oversizedFileBytes = 200 * 1024;

  Future<DoctorReport> inspect(String projectRoot) async {
    final root = p.normalize(projectRoot);
    final projectName = await _projectName(root);

    final categories = <DoctorCategoryResult>[
      await _checkEnvironment(root),
      await _checkDependencies(root),
      await _checkConfiguration(root),
      await _checkCodeQuality(root),
      await _checkArchitecture(root),
      await _checkTests(root),
      await _checkChico(root),
    ];

    return DoctorReport(
      projectName: projectName,
      projectRoot: root,
      categories: categories,
    );
  }

  /// Shows planned safe fixes; applies them unless [dryRun] is true.
  Future<DoctorFixResult> fix(String projectRoot, {bool dryRun = true}) async {
    final report = await inspect(projectRoot);
    final planned = <String>[];
    final applied = <String>[];

    for (final issue in report.fixableIssues) {
      final description = '${issue.fixId}: ${issue.message}';
      planned.add(description);
      if (dryRun) continue;
      await _applyFix(projectRoot, issue.fixId!);
      applied.add(description);
    }

    return DoctorFixResult(planned: planned, applied: applied, dryRun: dryRun);
  }

  Future<DoctorCategoryResult> _checkEnvironment(String root) async {
    final issues = <DoctorIssue>[];
    final flutterOk = await toolRunner.isFlutterAvailable();
    final dartOk = await toolRunner.isDartAvailable();

    if (!flutterOk) {
      issues.add(
        const DoctorIssue(
          severity: DoctorSeverity.high,
          code: 'env.flutter_missing',
          message: 'Flutter SDK is not available on PATH.',
        ),
      );
    }
    if (!dartOk) {
      issues.add(
        const DoctorIssue(
          severity: DoctorSeverity.high,
          code: 'env.dart_missing',
          message: 'Dart SDK is not available on PATH.',
        ),
      );
    }

    final status = issues.any((i) => i.severity == DoctorSeverity.high)
        ? DoctorStatus.fail
        : DoctorStatus.pass;
    return DoctorCategoryResult(
      id: 'environment',
      label: 'Environment',
      status: status,
      issues: issues,
    );
  }

  Future<DoctorCategoryResult> _checkDependencies(String root) async {
    final issues = <DoctorIssue>[];
    final pubspec = File(p.join(root, 'pubspec.yaml'));
    if (!pubspec.existsSync()) {
      issues.add(
        DoctorIssue(
          severity: DoctorSeverity.high,
          code: 'deps.pubspec_missing',
          message: 'pubspec.yaml is missing.',
          details: pubspec.path,
        ),
      );
      return DoctorCategoryResult(
        id: 'dependencies',
        label: 'Dependencies',
        status: DoctorStatus.fail,
        issues: issues,
      );
    }

    try {
      final loaded = loadYaml(await pubspec.readAsString());
      if (loaded is! YamlMap) {
        issues.add(
          const DoctorIssue(
            severity: DoctorSeverity.high,
            code: 'deps.pubspec_invalid',
            message: 'pubspec.yaml root must be a map.',
          ),
        );
      } else {
        if (!loaded.containsKey('name')) {
          issues.add(
            const DoctorIssue(
              severity: DoctorSeverity.high,
              code: 'deps.pubspec_name_missing',
              message: 'pubspec.yaml is missing a package name.',
            ),
          );
        }
        if (!loaded.containsKey('dependencies')) {
          issues.add(
            const DoctorIssue(
              severity: DoctorSeverity.medium,
              code: 'deps.section_missing',
              message: 'pubspec.yaml has no dependencies section.',
            ),
          );
        }
      }
    } on YamlException catch (error) {
      issues.add(
        DoctorIssue(
          severity: DoctorSeverity.high,
          code: 'deps.pubspec_yaml',
          message: 'pubspec.yaml contains invalid YAML.',
          details: error.message,
        ),
      );
    }

    final lock = File(p.join(root, 'pubspec.lock'));
    if (!lock.existsSync()) {
      issues.add(
        const DoctorIssue(
          severity: DoctorSeverity.low,
          code: 'deps.lock_missing',
          message: 'pubspec.lock is missing (run flutter pub get).',
        ),
      );
    }

    final status = issues.any((i) => i.severity == DoctorSeverity.high)
        ? DoctorStatus.fail
        : issues.isEmpty
        ? DoctorStatus.pass
        : DoctorStatus.warning;

    return DoctorCategoryResult(
      id: 'dependencies',
      label: 'Dependencies',
      status: status,
      issues: issues,
    );
  }

  Future<DoctorCategoryResult> _checkConfiguration(String root) async {
    final issues = <DoctorIssue>[];
    final configPath = ConfigPaths.projectConfigFile(root);
    if (!File(configPath).existsSync()) {
      issues.add(
        DoctorIssue(
          severity: DoctorSeverity.medium,
          code: 'config.missing',
          message: 'DevKit configuration is missing.',
          details: configPath,
          fixId: 'init_config',
        ),
      );
    } else {
      try {
        configService.resolve(projectRoot: root);
      } on ConfigException catch (error) {
        issues.add(
          DoctorIssue(
            severity: DoctorSeverity.high,
            code: 'config.invalid',
            message: error.message,
            details: error.details,
          ),
        );
      }
    }

    final status = issues.any((i) => i.severity == DoctorSeverity.high)
        ? DoctorStatus.fail
        : issues.isEmpty
        ? DoctorStatus.pass
        : DoctorStatus.warning;

    return DoctorCategoryResult(
      id: 'configuration',
      label: 'Configuration',
      status: status,
      issues: issues,
    );
  }

  Future<DoctorCategoryResult> _checkCodeQuality(String root) async {
    final issues = <DoctorIssue>[];
    final libDir = Directory(p.join(root, 'lib'));
    if (!libDir.existsSync()) {
      issues.add(
        const DoctorIssue(
          severity: DoctorSeverity.high,
          code: 'quality.lib_missing',
          message: 'lib/ directory is missing.',
          fixId: 'create_lib_dir',
        ),
      );
    } else {
      await for (final entity in libDir.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final length = await entity.length();
        if (length >= oversizedFileBytes) {
          issues.add(
            DoctorIssue(
              severity: DoctorSeverity.medium,
              code: 'quality.oversized_file',
              message: 'File exceeds ${oversizedFileBytes ~/ 1024}KB.',
              details: p.relative(entity.path, from: root),
            ),
          );
        }
      }
    }

    try {
      final manifest = GenerateManifest.load(root);
      for (final path in manifest.entries.keys) {
        if (!manifest.isUnchanged(path)) {
          issues.add(
            DoctorIssue(
              severity: DoctorSeverity.low,
              code: 'generate.manifest_drift',
              message: 'Generated file differs from the generate manifest.',
              details: path,
            ),
          );
        }
      }
    } on DevKitException catch (error) {
      issues.add(
        DoctorIssue(
          severity: DoctorSeverity.medium,
          code: 'generate.manifest_corrupt',
          message: error.message,
          details: error.details,
        ),
      );
    }

    final analysisOptions = File(p.join(root, 'analysis_options.yaml'));
    if (!analysisOptions.existsSync()) {
      issues.add(
        const DoctorIssue(
          severity: DoctorSeverity.low,
          code: 'quality.analysis_options_missing',
          message: 'analysis_options.yaml is missing.',
          fixId: 'create_analysis_options',
        ),
      );
    }

    final status = issues.any((i) => i.severity == DoctorSeverity.high)
        ? DoctorStatus.fail
        : issues.isEmpty
        ? DoctorStatus.pass
        : DoctorStatus.warning;

    return DoctorCategoryResult(
      id: 'code_quality',
      label: 'Code quality',
      status: status,
      issues: issues,
    );
  }

  Future<DoctorCategoryResult> _checkArchitecture(String root) async {
    if (!File(ConfigPaths.projectConfigFile(root)).existsSync()) {
      return const DoctorCategoryResult(
        id: 'architecture',
        label: 'Architecture',
        status: DoctorStatus.skip,
      );
    }

    final issues = <DoctorIssue>[];
    try {
      final resolved = configService.resolve(projectRoot: root);
      final architecture =
          resolved.config.features.defaultArchitecture.yamlValue;
      final expected = switch (architecture) {
        'layered' => ['lib/data', 'lib/domain', 'lib/presentation'],
        _ => ['lib/features', 'lib/core'],
      };
      for (final path in expected) {
        if (!Directory(p.join(root, path)).existsSync()) {
          issues.add(
            DoctorIssue(
              severity: DoctorSeverity.low,
              code: 'architecture.folder_missing',
              message: 'Expected architecture folder is missing.',
              details: path,
              fixId: 'create_architecture_folder:$path',
            ),
          );
        }
      }
    } on ConfigException {
      // Config category already reports invalid config.
    }

    final status = issues.isEmpty ? DoctorStatus.pass : DoctorStatus.warning;
    return DoctorCategoryResult(
      id: 'architecture',
      label: 'Architecture',
      status: status,
      issues: issues,
    );
  }

  Future<DoctorCategoryResult> _checkTests(String root) async {
    final issues = <DoctorIssue>[];
    final testDir = Directory(p.join(root, 'test'));
    if (!testDir.existsSync()) {
      issues.add(
        const DoctorIssue(
          severity: DoctorSeverity.medium,
          code: 'tests.dir_missing',
          message: 'test/ directory is missing.',
          fixId: 'create_test_dir',
        ),
      );
    } else {
      final hasDart = testDir
          .listSync(recursive: true)
          .whereType<File>()
          .any((file) => file.path.endsWith('_test.dart'));
      if (!hasDart) {
        issues.add(
          const DoctorIssue(
            severity: DoctorSeverity.medium,
            code: 'tests.none_found',
            message: 'No *_test.dart files were found under test/.',
          ),
        );
      }
    }

    final status = issues.isEmpty ? DoctorStatus.pass : DoctorStatus.warning;
    return DoctorCategoryResult(
      id: 'tests',
      label: 'Tests',
      status: status,
      issues: issues,
    );
  }

  Future<DoctorCategoryResult> _checkChico(String root) async {
    final issues = <DoctorIssue>[];
    final pubspecFile = File(p.join(root, 'pubspec.yaml'));
    if (!pubspecFile.existsSync() ||
        !File(ConfigPaths.projectConfigFile(root)).existsSync()) {
      return const DoctorCategoryResult(
        id: 'chico',
        label: 'Chico',
        status: DoctorStatus.skip,
      );
    }

    try {
      final resolved = configService.resolve(projectRoot: root);
      final editor = PubspecEditor.forProject(root);
      final deps = await editor.listDependencies();

      Future<void> checkEnabled({
        required bool enabled,
        required ChicoPackageId package,
      }) async {
        if (!enabled) return;
        if (!deps.containsKey(package.packageName)) {
          issues.add(
            DoctorIssue(
              severity: DoctorSeverity.medium,
              code: 'chico.missing_dependency',
              message:
                  '${package.packageName} is enabled in config but missing from pubspec.',
              fixId: 'add_chico:${package.packageName}',
            ),
          );
        }
      }

      await checkEnabled(
        enabled: resolved.config.chico.ui.enabled,
        package: ChicoPackageId.ui,
      );
      await checkEnabled(
        enabled: resolved.config.chico.kit.enabled,
        package: ChicoPackageId.kit,
      );
      await checkEnabled(
        enabled: resolved.config.chico.services.enabled,
        package: ChicoPackageId.services,
      );
    } on ConfigException {
      // Handled by configuration category.
    }

    final status = issues.isEmpty ? DoctorStatus.pass : DoctorStatus.warning;
    return DoctorCategoryResult(
      id: 'chico',
      label: 'Chico',
      status: status,
      issues: issues,
    );
  }

  Future<void> _applyFix(String root, String fixId) async {
    if (fixId == 'init_config') {
      await configService.initProjectConfig(
        projectRoot: root,
        config: DevKitConfigDefaults.create(
          projectName: await _projectName(root),
        ),
      );
      return;
    }
    if (fixId == 'create_lib_dir') {
      await Directory(p.join(root, 'lib')).create(recursive: true);
      return;
    }
    if (fixId == 'create_test_dir') {
      await Directory(p.join(root, 'test')).create(recursive: true);
      return;
    }
    if (fixId == 'create_analysis_options') {
      final file = File(p.join(root, 'analysis_options.yaml'));
      if (!file.existsSync()) {
        await file.writeAsString('''
include: package:flutter_lints/flutter.yaml
''');
      }
      return;
    }
    if (fixId.startsWith('create_architecture_folder:')) {
      final relative = fixId.split(':').skip(1).join(':');
      await Directory(p.join(root, relative)).create(recursive: true);
      return;
    }
    if (fixId.startsWith('add_chico:')) {
      final packageName = fixId.substring('add_chico:'.length);
      final package = ChicoPackageId.parse(packageName);
      final editor = PubspecEditor.forProject(root);
      await editor.ensureDependency(
        packageName: package.packageName,
        constraint: package.defaultConstraint,
      );
      return;
    }
  }

  Future<String> _projectName(String root) async {
    final pubspec = File(p.join(root, 'pubspec.yaml'));
    if (pubspec.existsSync()) {
      try {
        final loaded = loadYaml(await pubspec.readAsString());
        if (loaded is YamlMap && loaded['name'] is String) {
          return loaded['name'] as String;
        }
      } catch (_) {}
    }
    return p.basename(root);
  }
}
