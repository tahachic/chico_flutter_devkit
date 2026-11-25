import 'dart:io';

import 'package:path/path.dart' as p;

import '../config/config_service.dart';
import '../config/defaults.dart';
import '../config/models.dart';
import '../core/exceptions.dart';
import '../fs/safe_file_system.dart';
import '../generators/feature/feature_generator.dart';
import '../generators/registry.dart';
import '../generators/runner.dart';
import '../generators/shared/ui_imports.dart';
import '../integrations/chico/chico_integration_service.dart';
import '../integrations/chico/chico_packages.dart';
import '../pubspec/pubspec_editor.dart';
import 'flutter_cli.dart';
import 'material_ui_l10n_patch.dart';
import 'project_options.dart';
import 'starters/app_scaffold.dart';

/// Result of creating a Flutter project.
final class ProjectCreateResult {
  const ProjectCreateResult({
    required this.projectPath,
    required this.writtenFiles,
    required this.chicoPackages,
  });

  final String projectPath;
  final List<String> writtenFiles;
  final List<String> chicoPackages;
}

/// Creates Flutter applications with DevKit overlays and Chico integrations.
final class ProjectFactory {
  ProjectFactory({
    required this.configService,
    required this.flutterCli,
    ChicoIntegrationService? chicoIntegrationService,
    this.runPubGet = true,
  }) : chicoIntegrationService =
           chicoIntegrationService ??
           ChicoIntegrationService(configService: configService);

  final ConfigService configService;
  final FlutterCli flutterCli;
  final ChicoIntegrationService chicoIntegrationService;
  final bool runPubGet;

  Future<ProjectCreateResult> create(ProjectCreateOptions options) async {
    final name = options.normalizedName.snakeCase;
    if (!RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(name)) {
      throw InvalidUsageException(
        'Invalid project name "$name".',
        details: 'Use a valid Dart package name.',
      );
    }

    final projectPath = p.normalize(options.outputDirectory);
    if (Directory(projectPath).existsSync() &&
        Directory(projectPath).listSync().isNotEmpty) {
      throw ExecutionException(
        'Target directory is not empty.',
        details: projectPath,
      );
    }

    await flutterCli.createProject(
      name: name,
      organization: options.organization,
      outputDirectory: projectPath,
      platforms: options.platforms,
    );

    final materialApp =
        !options.enableChicoUi &&
        !options.enableChicoKit &&
        !options.enableChicoServices;
    final useMaterialUi =
        options.useMaterialUi ||
        (materialApp && await flutterCli.supportsMaterialUiPackage());
    final effective = ProjectCreateOptions(
      name: options.name,
      organization: options.organization,
      architecture: options.architecture,
      stateManagement: options.stateManagement,
      routing: options.routing,
      dependencyInjection: options.dependencyInjection,
      enableChicoUi: options.enableChicoUi,
      enableChicoKit: options.enableChicoKit,
      enableChicoServices: options.enableChicoServices,
      enableLocalization: options.enableLocalization,
      languages: options.languages,
      enableDarkMode: options.enableDarkMode,
      enableLogging: options.enableLogging,
      enableErrorHandling: options.enableErrorHandling,
      generateExampleFeature: options.generateExampleFeature,
      outputDirectory: options.outputDirectory,
      apiBaseUrl: options.apiBaseUrl,
      useMaterialUi: useMaterialUi,
      platforms: options.platforms,
    );

    final fs = SafeFileSystem(projectRoot: projectPath, createBackups: false);
    final overlay = AppScaffold.build(effective);
    final writeResult = await fs.applyWrites(overlay, force: true);

    // Stack dependencies for routing / state / DI / l10n.
    final pubspec = PubspecEditor.forProject(projectPath);
    await _ensureStackDependencies(pubspec, effective);
    if (effective.enableLocalization) {
      await pubspec.ensureSdkDependency('flutter_localizations');
      await pubspec.ensureDependency(packageName: 'intl', constraint: 'any');
      await pubspec.ensureFlutterGenerate(enabled: true);
    }
    if (effective.useMaterialUi && materialApp) {
      await pubspec.ensureDependency(
        packageName: UiImports.materialUiPackage,
        constraint: UiImports.materialUiConstraint,
      );
      await pubspec.ensureDependency(
        packageName: UiImports.cupertinoUiPackage,
        constraint: UiImports.cupertinoUiConstraint,
      );
    }

    final chicoPackages = <String>[];
    final selected = <ChicoPackageId>[
      if (options.enableChicoUi) ChicoPackageId.ui,
      if (options.enableChicoKit) ChicoPackageId.kit,
      if (options.enableChicoServices) ChicoPackageId.services,
    ];
    if (selected.isNotEmpty) {
      final integration = await chicoIntegrationService.setup(
        projectRoot: projectPath,
        packages: selected,
        writeBootstrap: true,
        force: true,
      );
      chicoPackages.addAll([
        ...integration.addedPackages,
        ...integration.alreadyPresent,
      ]);
    }

    final config =
        DevKitConfigDefaults.create(
          projectName: name,
          organization: options.organization,
        ).copyWith(
          project: ProjectConfig(
            name: name,
            architecture: effective.architecture,
            organization: effective.organization,
          ),
          flutter: FlutterStackConfig(
            stateManagement: effective.stateManagement,
            routing: effective.routing,
            dependencyInjection: effective.dependencyInjection,
            localization: LocalizationConfig(
              enabled: effective.enableLocalization,
              languages: effective.enableLocalization
                  ? (effective.languages.isEmpty
                        ? const ['en']
                        : effective.languages)
                  : const ['en'],
            ),
          ),
          chico: ChicoIntegrationsConfig(
            ui: ChicoPackageToggle(
              enabled: effective.enableChicoUi,
              version: DefaultChicoVersions.ui,
            ),
            kit: ChicoPackageToggle(
              enabled: effective.enableChicoKit,
              version: DefaultChicoVersions.kit,
            ),
            services: ChicoPackageToggle(
              enabled: effective.enableChicoServices,
              version: DefaultChicoVersions.services,
            ),
          ),
          features: FeaturesConfig(
            defaultArchitecture: effective.architecture,
            generateTests: true,
            generateDocumentation: true,
          ),
        );

    await configService.initProjectConfig(
      projectRoot: projectPath,
      config: config,
      force: true,
    );

    if (effective.generateExampleFeature) {
      final runner = GeneratorRunner(
        registry: GeneratorRegistry(generators: [FeatureGenerator()]),
        configService: configService,
      );
      await runner.run(
        projectRoot: projectPath,
        generatorName: 'feature',
        targetName: 'example',
        extra: {
          'architecture': effective.architecture.yamlValue,
          'tests': false,
          'remote': true,
        },
      );
    }

    if (runPubGet) {
      await flutterCli.pubGet(projectPath);
      if (effective.enableLocalization) {
        await flutterCli.genL10n(projectPath);
      }
      if (effective.useMaterialUi && materialApp) {
        // Migrates scaffold + gen-l10n output off deprecated flutter/material.
        await flutterCli.migrateDesignWidgets(projectPath);
        if (effective.enableLocalization) {
          // gen-l10n still emits GlobalMaterial/Cupertino from
          // flutter_localizations; rewrite to material_ui delegates.
          await MaterialUiL10nPatch.apply(projectPath);
        }
      }
    }

    return ProjectCreateResult(
      projectPath: projectPath,
      writtenFiles: writeResult.results
          .map((result) => result.relativePath)
          .toList(growable: false),
      chicoPackages: chicoPackages.toSet().toList(growable: false),
    );
  }

  Future<void> _ensureStackDependencies(
    PubspecEditor pubspec,
    ProjectCreateOptions options,
  ) async {
    if (options.routing == Routing.goRouter) {
      await pubspec.ensureDependency(
        packageName: 'go_router',
        constraint: '^14.0.0',
      );
    }
    if (options.dependencyInjection == DependencyInjection.getIt) {
      await pubspec.ensureDependency(
        packageName: 'get_it',
        constraint: '^8.0.0',
      );
    }
    if (options.dependencyInjection == DependencyInjection.riverpod ||
        options.stateManagement == StateManagement.riverpod) {
      await pubspec.ensureDependency(
        packageName: 'flutter_riverpod',
        constraint: '^2.6.1',
      );
    }
    switch (options.stateManagement) {
      case StateManagement.bloc:
      case StateManagement.cubit:
        await pubspec.ensureDependency(
          packageName: 'flutter_bloc',
          constraint: '^9.0.0',
        );
      case StateManagement.riverpod:
        break; // ensured above
      case StateManagement.provider:
        await pubspec.ensureDependency(
          packageName: 'provider',
          constraint: '^6.1.2',
        );
    }
  }
}
