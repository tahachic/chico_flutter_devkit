import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import '../config/config_service.dart';
import '../config/defaults.dart';
import '../config/models.dart';
import '../core/exceptions.dart';
import '../fs/safe_file_system.dart';
import '../fs/write_plan.dart';
import '../generators/feature/feature_integration.dart';
import '../generators/shared/ui_imports.dart';
import '../pubspec/pubspec_editor.dart';
import 'flutter_cli.dart';

/// Result of adopting an existing Flutter app into the DevKit matrix.
final class AdoptResult {
  const AdoptResult({
    required this.projectName,
    required this.createdFiles,
    required this.skippedExisting,
    required this.message,
  });

  final String projectName;
  final List<String> createdFiles;
  final List<String> skippedExisting;
  final String message;
}

/// Brownfield adopt: config + DevKit anchors without inventing a parallel app.
final class AdoptService {
  AdoptService({required this.configService, FlutterCli? flutterCli})
    : flutterCli = flutterCli ?? ProcessFlutterCli();

  final ConfigService configService;
  final FlutterCli flutterCli;

  Future<AdoptResult> adopt({
    required String projectRoot,
    required Architecture architecture,
    required StateManagement state,
    required Routing routing,
    required DependencyInjection di,
    bool forceConfig = false,
    bool dryRun = false,
  }) async {
    final root = p.normalize(projectRoot);
    final pubspec = File(p.join(root, 'pubspec.yaml'));
    if (!pubspec.existsSync()) {
      throw const InvalidUsageException(
        'No pubspec.yaml found.',
        details: 'Run adopt from a Flutter project root.',
      );
    }
    final raw = loadYaml(pubspec.readAsStringSync());
    if (raw is! YamlMap || raw['flutter'] == null) {
      throw const InvalidUsageException(
        'pubspec.yaml is not a Flutter project.',
        details: 'Expected a top-level `flutter:` section.',
      );
    }
    final name = (raw['name']?.toString() ?? 'app').trim();
    if (name.isEmpty) {
      throw const InvalidUsageException('pubspec.yaml is missing `name`.');
    }

    final homePath = FeatureIntegration.homePagePath;
    final homeFile = File(p.join(root, homePath));
    if (homeFile.existsSync()) {
      final home = homeFile.readAsStringSync();
      if (!home.contains(FeatureIntegration.homeBegin)) {
        throw InvalidUsageException(
          'Home page exists without DevKit anchors.',
          details:
              '$homePath\n'
              'Recovery:\n'
              '  1) Add ${FeatureIntegration.homeBegin} / '
              '${FeatureIntegration.homeEnd} inside the Home children list, or\n'
              '  2) Move/rename the file so adopt can scaffold a marked Home.\n'
              'DevKit will not replace your Home page.\n'
              'After adopt: `devkit upgrade scaffolds` refreshes route/DI stubs.',
        );
      }
    }

    _validateOrPrepareRouter(root: root, routing: routing);
    _validateOrPrepareDi(root: root, di: di);

    final config = DevKitConfigDefaults.create(projectName: name).copyWith(
      project: DevKitConfigDefaults.create(
        projectName: name,
      ).project.copyWith(architecture: architecture),
      flutter: DevKitConfigDefaults.create(projectName: name).flutter.copyWith(
        stateManagement: state,
        routing: routing,
        dependencyInjection: di,
      ),
      features: DevKitConfigDefaults.create(
        projectName: name,
      ).features.copyWith(defaultArchitecture: architecture),
    );

    final useMaterialUi = await flutterCli.supportsMaterialUiPackage();

    if (!dryRun) {
      await configService.initProjectConfig(
        projectRoot: root,
        config: config,
        force: forceConfig,
      );
      final pubspec = PubspecEditor.forProject(root);
      await _ensureStackDependencies(
        pubspec,
        routing: routing,
        state: state,
        di: di,
      );
      if (useMaterialUi) {
        await pubspec.ensureDependency(
          packageName: UiImports.materialUiPackage,
          constraint: UiImports.materialUiConstraint,
        );
        await pubspec.ensureDependency(
          packageName: UiImports.cupertinoUiPackage,
          constraint: UiImports.cupertinoUiConstraint,
        );
      }
    }

    final writes = <PlannedFileWrite>[
      ..._routingScaffold(routing: routing, project: name),
      ..._diScaffold(di: di, project: name),
      if (!homeFile.existsSync())
        PlannedFileWrite(
          relativePath: homePath,
          content: FeatureIntegration.freshMaterialHome(
            projectTitle: _pascalize(name),
            routing: routing,
            useMaterialUi: useMaterialUi,
          ),
        ),
    ];

    final fs = SafeFileSystem(projectRoot: root);
    final created = <String>[];
    final skipped = <String>[];
    final toApply = <PlannedFileWrite>[];

    for (final write in writes) {
      final absolute = p.join(root, write.relativePath);
      if (File(absolute).existsSync()) {
        skipped.add(write.relativePath);
        continue;
      }
      created.add(write.relativePath);
      toApply.add(write);
    }

    if (!dryRun && toApply.isNotEmpty) {
      await fs.applyWrites(toApply, dryRun: false);
    }

    return AdoptResult(
      projectName: name,
      createdFiles: created,
      skippedExisting: skipped,
      message: dryRun
          ? 'Dry-run: would write ${created.length} file(s); '
                'skip ${skipped.length} existing.'
          : 'Adopted $name into the DevKit matrix.\n'
                'Config: .chico/devkit.yaml\n'
                'Created: ${created.isEmpty ? '(none)' : created.join(', ')}\n'
                'Next: devkit generate feature <name> · devkit doctor',
    );
  }

  void _validateOrPrepareRouter({
    required String root,
    required Routing routing,
  }) {
    final router = File(
      p.join(root, 'lib', 'core', 'routing', 'app_router.dart'),
    );
    final routes = File(
      p.join(root, 'lib', 'core', 'routing', 'feature_routes.dart'),
    );
    if (router.existsSync()) {
      final source = router.readAsStringSync();
      if (!source.contains('AppRouter') || !source.contains('featureRoutes')) {
        throw const InvalidUsageException(
          'Existing app_router.dart is missing DevKit anchors.',
          details:
              'Expected AppRouter and featureRoutes.\n'
              'Recovery: align with DevKit create output, or remove '
              'lib/core/routing/app_router.dart so adopt can scaffold it.\n'
              'Later: `devkit upgrade scaffolds` refreshes missing stubs.',
        );
      }
    }
    if (routes.existsSync()) {
      final source = routes.readAsStringSync();
      if (!source.contains(FeatureIntegration.routeImportsBegin) ||
          !source.contains(FeatureIntegration.routesBegin)) {
        throw const InvalidUsageException(
          'Existing feature_routes.dart is missing DevKit markers.',
          details:
              'Expected ${FeatureIntegration.routeImportsBegin} and '
              '${FeatureIntegration.routesBegin}.',
        );
      }
    }
    // Missing router/routes → will be created by scaffold writes.
    if (!router.existsSync() && routing == Routing.goRouter) {
      // ok — scaffold creates both
    }
  }

  void _validateOrPrepareDi({
    required String root,
    required DependencyInjection di,
  }) {
    switch (di) {
      case DependencyInjection.getIt:
        final regs = File(
          p.join(root, 'lib', 'core', 'di', 'feature_registrations.dart'),
        );
        if (regs.existsSync()) {
          final source = regs.readAsStringSync();
          if (!source.contains(FeatureIntegration.diImportsBegin) ||
              !source.contains(FeatureIntegration.regsBegin)) {
            throw const InvalidUsageException(
              'Existing feature_registrations.dart is missing DevKit markers.',
              details:
                  'Expected ${FeatureIntegration.diImportsBegin} and '
                  '${FeatureIntegration.regsBegin}.\n'
                  'Recovery: add the markers, or remove the file so adopt can '
                  'scaffold it. Then: `devkit upgrade scaffolds`.',
            );
          }
        }
        final injector = File(
          p.join(root, 'lib', 'core', 'di', 'injector.dart'),
        );
        if (injector.existsSync()) {
          final source = injector.readAsStringSync();
          if (!source.contains('registerFeatures(getIt);')) {
            throw const InvalidUsageException(
              'Existing injector.dart is missing registerFeatures(getIt);',
              details:
                  'Add the call site so feature DI can hook in, or remove '
                  'injector.dart for adopt to scaffold get_it.',
            );
          }
        }
      case DependencyInjection.riverpod:
        final providers = File(
          p.join(root, 'lib', 'core', 'di', 'feature_providers.dart'),
        );
        if (providers.existsSync() &&
            !providers.readAsStringSync().contains(
              FeatureIntegration.providerExportsBegin,
            )) {
          throw const InvalidUsageException(
            'Existing feature_providers.dart is missing DevKit markers.',
          );
        }
      case DependencyInjection.manual:
        final factories = File(
          p.join(root, 'lib', 'core', 'di', 'feature_factories.dart'),
        );
        if (factories.existsSync() &&
            !factories.readAsStringSync().contains(
              FeatureIntegration.factoriesBegin,
            )) {
          throw const InvalidUsageException(
            'Existing feature_factories.dart is missing DevKit markers.',
          );
        }
    }
  }

  List<PlannedFileWrite> _routingScaffold({
    required Routing routing,
    required String project,
  }) {
    final homeImport =
        "import 'package:$project/features/home/presentation/pages/home_page.dart';";
    if (routing == Routing.goRouter) {
      return [
        const PlannedFileWrite(
          relativePath: 'lib/core/routing/feature_routes.dart',
          content:
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
        ),
        PlannedFileWrite(
          relativePath: 'lib/core/routing/app_router.dart',
          content:
              '''
import 'package:go_router/go_router.dart';

$homeImport
import 'feature_routes.dart';

/// Application router (go_router).
abstract final class AppRouter {
  static final GoRouter router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const HomePage(),
      ),
      ...featureRoutes,
    ],
  );
}
''',
        ),
      ];
    }
    return [
      const PlannedFileWrite(
        relativePath: 'lib/core/routing/feature_routes.dart',
        content:
            '''
import 'package:flutter/widgets.dart';

${FeatureIntegration.routeImportsBegin}
${FeatureIntegration.routeImportsEnd}

/// Named routes appended by `devkit generate feature`.
Map<String, WidgetBuilder> get featureRoutes => {
  ${FeatureIntegration.routesBegin}
  ${FeatureIntegration.routesEnd}
};
''',
      ),
      PlannedFileWrite(
        relativePath: 'lib/core/routing/app_router.dart',
        content:
            '''
import 'package:flutter/widgets.dart';

$homeImport
import 'feature_routes.dart';

/// Application router (Navigator 1.0 named routes).
abstract final class AppRouter {
  static const home = '/';

  static Map<String, WidgetBuilder> get routes => {
        home: (_) => const HomePage(),
        ...featureRoutes,
      };
}
''',
      ),
    ];
  }

  List<PlannedFileWrite> _diScaffold({
    required DependencyInjection di,
    required String project,
  }) {
    return switch (di) {
      DependencyInjection.getIt => [
        const PlannedFileWrite(
          relativePath: 'lib/core/di/feature_registrations.dart',
          content:
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
        ),
        const PlannedFileWrite(
          relativePath: 'lib/core/di/injector.dart',
          content: '''
import 'package:get_it/get_it.dart';

import 'feature_registrations.dart';

final GetIt getIt = GetIt.instance;

Future<void> configureDependencies() async {
  registerFeatures(getIt);
}
''',
        ),
      ],
      DependencyInjection.riverpod => [
        const PlannedFileWrite(
          relativePath: 'lib/core/di/feature_providers.dart',
          content:
              '''
${FeatureIntegration.providerExportsBegin}
${FeatureIntegration.providerExportsEnd}
''',
        ),
      ],
      DependencyInjection.manual => [
        const PlannedFileWrite(
          relativePath: 'lib/core/di/feature_factories.dart',
          content:
              '''
${FeatureIntegration.factoryImportsBegin}
${FeatureIntegration.factoryImportsEnd}

abstract final class FeatureFactories {
  ${FeatureIntegration.factoriesBegin}
  ${FeatureIntegration.factoriesEnd}
}
''',
        ),
      ],
    };
  }

  Future<void> _ensureStackDependencies(
    PubspecEditor pubspec, {
    required Routing routing,
    required StateManagement state,
    required DependencyInjection di,
  }) async {
    if (routing == Routing.goRouter) {
      await pubspec.ensureDependency(
        packageName: 'go_router',
        constraint: '^14.0.0',
      );
    }
    if (di == DependencyInjection.getIt) {
      await pubspec.ensureDependency(
        packageName: 'get_it',
        constraint: '^8.0.0',
      );
    }
    if (di == DependencyInjection.riverpod ||
        state == StateManagement.riverpod) {
      await pubspec.ensureDependency(
        packageName: 'flutter_riverpod',
        constraint: '^2.6.1',
      );
    }
    switch (state) {
      case StateManagement.bloc:
      case StateManagement.cubit:
        await pubspec.ensureDependency(
          packageName: 'flutter_bloc',
          constraint: '^9.0.0',
        );
      case StateManagement.riverpod:
        break;
      case StateManagement.provider:
        await pubspec.ensureDependency(
          packageName: 'provider',
          constraint: '^6.1.2',
        );
    }
  }

  static String _pascalize(String snake) {
    final parts = snake.split(RegExp(r'[^A-Za-z0-9]+'));
    return parts
        .where((p) => p.isNotEmpty)
        .map((p) => '${p[0].toUpperCase()}${p.substring(1)}')
        .join();
  }
}
