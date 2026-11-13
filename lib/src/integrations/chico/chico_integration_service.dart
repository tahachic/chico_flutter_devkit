import 'dart:io';

import 'package:path/path.dart' as p;

import '../../config/config_service.dart';
import '../../config/defaults.dart';
import '../../config/models.dart';
import '../../core/exceptions.dart';
import '../../fs/safe_file_system.dart';
import '../../fs/write_plan.dart';
import '../../pubspec/pubspec_editor.dart';
import 'boot_snippets.dart';
import 'chico_packages.dart';

/// Result of adding / setting up Chico packages.
final class ChicoIntegrationResult {
  const ChicoIntegrationResult({
    required this.addedPackages,
    required this.alreadyPresent,
    required this.docs,
    this.bootstrapPath,
  });

  final List<String> addedPackages;
  final List<String> alreadyPresent;
  final List<String> docs;
  final String? bootstrapPath;
}

/// Adds Chico packages and optional bootstrap helpers using verified APIs.
final class ChicoIntegrationService {
  ChicoIntegrationService({required this.configService});

  final ConfigService configService;

  Future<ChicoIntegrationResult> addPackage({
    required String projectRoot,
    required ChicoPackageId package,
    String? versionConstraint,
    bool writeBootstrap = false,
    bool force = false,
  }) {
    return setup(
      projectRoot: projectRoot,
      packages: [package],
      versionOverrides: {package: ?versionConstraint},
      writeBootstrap: writeBootstrap,
      force: force,
    );
  }

  Future<ChicoIntegrationResult> setup({
    required String projectRoot,
    List<ChicoPackageId>? packages,
    Map<ChicoPackageId, String> versionOverrides = const {},
    bool writeBootstrap = true,
    bool force = false,
  }) async {
    final pubspec = PubspecEditor.forProject(projectRoot);
    if (!pubspec.file.existsSync()) {
      throw ExecutionException(
        'Not a Dart/Flutter project.',
        details: 'Missing ${pubspec.file.path}',
      );
    }

    final resolved = configService.resolve(projectRoot: projectRoot);
    final selected = packages ?? _enabledFromConfig(resolved.config.chico);

    // Honor dependency order: ui → kit → services
    final ordered = _ordered(selected);
    final added = <String>[];
    final present = <String>[];
    final docs = <String>[];

    for (final package in ordered) {
      // Enforce dependency prerequisites.
      if (package == ChicoPackageId.kit &&
          !ordered.contains(ChicoPackageId.ui) &&
          !await pubspec.hasDependency(ChicoPackageId.ui.packageName)) {
        final uiConstraint =
            versionOverrides[ChicoPackageId.ui] ??
            resolved.config.chico.ui.version ??
            DefaultChicoVersions.ui;
        final changed = await pubspec.ensureDependency(
          packageName: ChicoPackageId.ui.packageName,
          constraint: uiConstraint,
        );
        if (changed) {
          added.add(ChicoPackageId.ui.packageName);
        } else {
          present.add(ChicoPackageId.ui.packageName);
        }
        docs.add(ChicoBootSnippets.documentationFor(ChicoPackageId.ui));
      }
      if (package == ChicoPackageId.services) {
        if (!await pubspec.hasDependency(ChicoPackageId.kit.packageName) &&
            !ordered.contains(ChicoPackageId.kit)) {
          await setup(
            projectRoot: projectRoot,
            packages: const [ChicoPackageId.kit],
            versionOverrides: versionOverrides,
            writeBootstrap: false,
            force: force,
          );
        }
      }

      final constraint =
          versionOverrides[package] ??
          _constraintFromConfig(resolved.config, package) ??
          package.defaultConstraint;
      final changed = await pubspec.ensureDependency(
        packageName: package.packageName,
        constraint: constraint,
      );
      if (changed) {
        added.add(package.packageName);
      } else {
        present.add(package.packageName);
      }
      docs.add(ChicoBootSnippets.documentationFor(package));
    }

    String? bootstrapPath;
    if (writeBootstrap) {
      bootstrapPath = await _writeBootstrap(
        projectRoot: projectRoot,
        force: force,
        chico: _configWithPackages(resolved.config.chico, ordered),
      );
    }

    return ChicoIntegrationResult(
      addedPackages: added,
      alreadyPresent: present,
      docs: docs.toSet().toList(growable: false),
      bootstrapPath: bootstrapPath,
    );
  }

  List<ChicoPackageId> _enabledFromConfig(ChicoIntegrationsConfig chico) {
    return [
      if (chico.ui.enabled) ChicoPackageId.ui,
      if (chico.kit.enabled) ChicoPackageId.kit,
      if (chico.services.enabled) ChicoPackageId.services,
    ];
  }

  List<ChicoPackageId> _ordered(List<ChicoPackageId> packages) {
    final set = packages.toSet();
    return [
      if (set.contains(ChicoPackageId.ui)) ChicoPackageId.ui,
      if (set.contains(ChicoPackageId.kit)) ChicoPackageId.kit,
      if (set.contains(ChicoPackageId.services)) ChicoPackageId.services,
    ];
  }

  String? _constraintFromConfig(DevKitConfig config, ChicoPackageId id) {
    return switch (id) {
      ChicoPackageId.ui => config.chico.ui.version,
      ChicoPackageId.kit => config.chico.kit.version,
      ChicoPackageId.services => config.chico.services.version,
    };
  }

  ChicoIntegrationsConfig _configWithPackages(
    ChicoIntegrationsConfig base,
    List<ChicoPackageId> packages,
  ) {
    return ChicoIntegrationsConfig(
      ui: ChicoPackageToggle(
        enabled: packages.contains(ChicoPackageId.ui) || base.ui.enabled,
        version: base.ui.version ?? DefaultChicoVersions.ui,
      ),
      kit: ChicoPackageToggle(
        enabled: packages.contains(ChicoPackageId.kit) || base.kit.enabled,
        version: base.kit.version ?? DefaultChicoVersions.kit,
      ),
      services: ChicoPackageToggle(
        enabled:
            packages.contains(ChicoPackageId.services) || base.services.enabled,
        version: base.services.version ?? DefaultChicoVersions.services,
      ),
    );
  }

  Future<String?> _writeBootstrap({
    required String projectRoot,
    required bool force,
    required ChicoIntegrationsConfig chico,
  }) async {
    if (!chico.ui.enabled && !chico.kit.enabled && !chico.services.enabled) {
      return null;
    }

    final fs = SafeFileSystem(projectRoot: projectRoot, createBackups: true);
    final relative = 'lib/core/chico_bootstrap.dart';
    final content =
        '''
${ChicoBootSnippets.importLine(chico)}

/// Verified Chico bootstrap helpers generated by DevKit.
abstract final class ChicoBootstrap {
${chico.services.enabled ? '''
  /// Initializes Chico services. Call before runApp.
  static Future<void> init({
    String baseUrl = 'https://api.example.com',
  }) {
    return ChicoServices.init(baseUrl: baseUrl);
  }
''' : '''
  /// chico_kit / chico_ui require no init call.
  static Future<void> init() async {}
'''}
}
''';

    final absolute = p.join(projectRoot, relative);
    if (File(absolute).existsSync() && !force) {
      return relative;
    }

    await fs.applyWrites([
      PlannedFileWrite(
        relativePath: relative,
        content: content,
        mode: force ? FileWriteMode.overwrite : FileWriteMode.create,
      ),
    ], force: force);
    return relative;
  }
}
