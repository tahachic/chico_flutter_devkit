import 'dart:io';

import 'package:path/path.dart' as p;

import '../../config/models.dart';
import '../../fs/write_plan.dart';
import '../context.dart';
import '../shared/ui_imports.dart';
import 'feature_layout.dart';

/// Append-safe route / DI / home hooks for generated features.
abstract final class FeatureIntegration {
  static const routeImportsBegin = '// <devkit:feature-route-imports>';
  static const routeImportsEnd = '// </devkit:feature-route-imports>';
  static const routesBegin = '// <devkit:feature-routes>';
  static const routesEnd = '// </devkit:feature-routes>';
  static const diImportsBegin = '// <devkit:feature-di-imports>';
  static const diImportsEnd = '// </devkit:feature-di-imports>';
  static const regsBegin = '// <devkit:feature-registrations>';
  static const regsEnd = '// </devkit:feature-registrations>';
  static const providerExportsBegin = '// <devkit:feature-provider-exports>';
  static const providerExportsEnd = '// </devkit:feature-provider-exports>';
  static const factoryImportsBegin = '// <devkit:feature-factory-imports>';
  static const factoryImportsEnd = '// </devkit:feature-factory-imports>';
  static const factoriesBegin = '// <devkit:feature-factories>';
  static const factoriesEnd = '// </devkit:feature-factories>';
  static const homeBegin = '// <devkit:home-features>';
  static const homeEnd = '// </devkit:home-features>';

  static const featureRoutesPath = 'lib/core/routing/feature_routes.dart';
  static const featureRegistrationsPath =
      'lib/core/di/feature_registrations.dart';
  static const featureProvidersPath = 'lib/core/di/feature_providers.dart';
  static const featureFactoriesPath = 'lib/core/di/feature_factories.dart';
  static const homePagePath =
      'lib/features/home/presentation/pages/home_page.dart';

  /// Planned writes that upsert this feature into create-time registries.
  static List<PlannedFileWrite> planHooks({
    required GenerationContext context,
    required FeatureLayout layout,
    required bool includeRemote,
    required bool includeLocal,
    bool useMaterialUi = false,
  }) {
    final project = context.config.project.name;
    final useChico =
        context.config.chico.ui.enabled ||
        context.config.chico.kit.enabled ||
        context.config.chico.services.enabled;
    final writes = <PlannedFileWrite>[];

    final routing = context.config.flutter.routing;
    writes.add(
      PlannedFileWrite(
        relativePath: featureRoutesPath,
        content: upsertFeatureRoutes(
          root: context.projectRoot,
          project: project,
          layout: layout,
          routing: routing,
        ),
        mode: FileWriteMode.overwrite,
      ),
    );
    writes.add(
      PlannedFileWrite(
        relativePath: homePagePath,
        content: upsertHomeLink(
          root: context.projectRoot,
          layout: layout,
          useChico: useChico,
          useMaterialUi: useMaterialUi,
          projectTitle: context.config.project.name,
          routing: routing,
        ),
        mode: FileWriteMode.overwrite,
      ),
    );

    switch (context.config.flutter.dependencyInjection) {
      case DependencyInjection.getIt:
        writes.add(
          PlannedFileWrite(
            relativePath: featureRegistrationsPath,
            content: upsertRegistrations(
              root: context.projectRoot,
              project: project,
              layout: layout,
              includeRemote: includeRemote,
              includeLocal: includeLocal,
            ),
            mode: FileWriteMode.overwrite,
          ),
        );
      case DependencyInjection.riverpod:
        if (context.config.flutter.stateManagement ==
            StateManagement.riverpod) {
          writes.add(
            PlannedFileWrite(
              relativePath: featureProvidersPath,
              content: upsertProviderExport(
                root: context.projectRoot,
                project: project,
                layout: layout,
              ),
              mode: FileWriteMode.overwrite,
            ),
          );
        }
      case DependencyInjection.manual:
        writes.add(
          PlannedFileWrite(
            relativePath: featureFactoriesPath,
            content: upsertManualFactory(
              root: context.projectRoot,
              project: project,
              layout: layout,
              includeRemote: includeRemote,
              includeLocal: includeLocal,
            ),
            mode: FileWriteMode.overwrite,
          ),
        );
    }

    return writes;
  }

  static String upsertFeatureRoutes({
    required String root,
    required String project,
    required FeatureLayout layout,
    required Routing routing,
  }) {
    final pageImport = layout.packageImport(project, layout.page);
    final path = '/features/${layout.snake}';
    final routeEntry = routing == Routing.goRouter
        ? '''
  GoRoute(
    path: '$path',
    name: '${layout.snake}',
    builder: (context, state) => const ${layout.pascal}Page(),
  ),'''
        : '''
  '$path': (_) => const ${layout.pascal}Page(),''';

    var source =
        _read(root, featureRoutesPath) ?? freshFeatureRoutes(routing: routing);
    final expectsGoRouter = routing == Routing.goRouter;
    final looksLikeGoRouter = source.contains('List<RouteBase>');
    if (!source.contains(routeImportsBegin) ||
        !source.contains(routesBegin) ||
        looksLikeGoRouter != expectsGoRouter) {
      source = freshFeatureRoutes(routing: routing);
    }
    source = upsertLine(
      source,
      begin: routeImportsBegin,
      end: routeImportsEnd,
      entry: pageImport,
      identity: pageImport,
    );
    source = upsertLine(
      source,
      begin: routesBegin,
      end: routesEnd,
      entry: routeEntry,
      identity: path,
    );
    return source;
  }

  static String freshFeatureRoutes({required Routing routing}) {
    if (routing == Routing.goRouter) {
      return '''
import 'package:go_router/go_router.dart';

$routeImportsBegin
$routeImportsEnd

/// GoRoutes appended by `devkit generate feature`.
List<RouteBase> get featureRoutes => [
$routesBegin
$routesEnd
];
''';
    }
    return '''
import 'package:flutter/widgets.dart';

$routeImportsBegin
$routeImportsEnd

/// Named routes appended by `devkit generate feature`.
Map<String, WidgetBuilder> get featureRoutes => {
$routesBegin
$routesEnd
};
''';
  }

  static String upsertRegistrations({
    required String root,
    required String project,
    required FeatureLayout layout,
    required bool includeRemote,
    required bool includeLocal,
  }) {
    final importLines = <String>[
      if (includeRemote) layout.packageImport(project, layout.remoteDatasource),
      if (includeLocal) layout.packageImport(project, layout.localDatasource),
      layout.packageImport(project, layout.repositoryContract),
      layout.packageImport(project, layout.repositoryImpl),
      layout.packageImport(project, layout.getUseCase),
    ];
    final ctorArgs = [
      if (includeRemote) 'remote: getIt()',
      if (includeLocal) 'local: getIt()',
    ].join(', ');

    final body = StringBuffer();
    if (includeRemote) {
      body.writeln('''
  if (!getIt.isRegistered<${layout.pascal}RemoteDataSource>()) {
    getIt.registerLazySingleton<${layout.pascal}RemoteDataSource>(
      ${layout.pascal}RemoteDataSource.new,
    );
  }''');
    }
    if (includeLocal) {
      body.writeln('''
  if (!getIt.isRegistered<${layout.pascal}LocalDataSource>()) {
    getIt.registerLazySingleton<${layout.pascal}LocalDataSource>(
      ${layout.pascal}LocalDataSource.new,
    );
  }''');
    }
    body.writeln('''
  if (!getIt.isRegistered<${layout.pascal}Repository>()) {
    getIt.registerLazySingleton<${layout.pascal}Repository>(
      () => ${layout.pascal}RepositoryImpl($ctorArgs),
    );
  }
  if (!getIt.isRegistered<Get${layout.pascal}List>()) {
    getIt.registerFactory<Get${layout.pascal}List>(
      () => Get${layout.pascal}List(getIt()),
    );
  }''');

    var source = _read(root, featureRegistrationsPath) ?? freshRegistrations();
    if (!source.contains(diImportsBegin) || !source.contains(regsBegin)) {
      source = freshRegistrations();
    }
    for (final line in importLines) {
      source = upsertLine(
        source,
        begin: diImportsBegin,
        end: diImportsEnd,
        entry: line,
        identity: line,
      );
    }
    source = upsertLine(
      source,
      begin: regsBegin,
      end: regsEnd,
      entry: body.toString().trimRight(),
      identity: '${layout.pascal}Repository',
    );
    return source;
  }

  static String freshRegistrations() =>
      '''
import 'package:get_it/get_it.dart';

$diImportsBegin
$diImportsEnd

/// Feature DI registrations appended by `devkit generate feature`.
void registerFeatures(GetIt getIt) {
$regsBegin
$regsEnd
}
''';

  static String upsertProviderExport({
    required String root,
    required String project,
    required FeatureLayout layout,
  }) {
    final providersPath =
        '${layout.stateDir(StateManagement.riverpod)}/${layout.snake}_providers.dart';
    final exportLine =
        "export 'package:$project/${providersPath.replaceFirst(RegExp(r'^lib/'), '')}';";

    var source = _read(root, featureProvidersPath) ?? freshProviderExports();
    if (!source.contains(providerExportsBegin)) {
      source = freshProviderExports();
    }
    return upsertLine(
      source,
      begin: providerExportsBegin,
      end: providerExportsEnd,
      entry: exportLine,
      identity: '${layout.snake}_providers.dart',
    );
  }

  static String freshProviderExports() =>
      '''
$providerExportsBegin
$providerExportsEnd

/// Barrel of feature providers — appended by `devkit generate feature`.
''';

  static String upsertManualFactory({
    required String root,
    required String project,
    required FeatureLayout layout,
    required bool includeRemote,
    required bool includeLocal,
  }) {
    final importLines = <String>[
      if (includeRemote) layout.packageImport(project, layout.remoteDatasource),
      if (includeLocal) layout.packageImport(project, layout.localDatasource),
      layout.packageImport(project, layout.repositoryImpl),
      layout.packageImport(project, layout.getUseCase),
    ];
    final ctorArgs = [
      if (includeRemote) 'remote: ${layout.pascal}RemoteDataSource()',
      if (includeLocal) 'local: ${layout.pascal}LocalDataSource()',
    ].join(', ');
    final method =
        '''
  static Get${layout.pascal}List ${layout.camel}List() {
    final repository = ${layout.pascal}RepositoryImpl($ctorArgs);
    return Get${layout.pascal}List(repository);
  }''';

    var source = _read(root, featureFactoriesPath) ?? freshFeatureFactories();
    if (!source.contains(factoryImportsBegin) ||
        !source.contains(factoriesBegin)) {
      source = freshFeatureFactories();
    }
    for (final line in importLines) {
      source = upsertLine(
        source,
        begin: factoryImportsBegin,
        end: factoryImportsEnd,
        entry: line,
        identity: line,
      );
    }
    return upsertLine(
      source,
      begin: factoriesBegin,
      end: factoriesEnd,
      entry: method,
      identity: '${layout.camel}List()',
    );
  }

  static String freshFeatureFactories() =>
      '''
$factoryImportsBegin
$factoryImportsEnd

/// Feature factories appended by `devkit generate feature`.
abstract final class FeatureFactories {
$factoriesBegin
$factoriesEnd
}
''';

  static String upsertHomeLink({
    required String root,
    required FeatureLayout layout,
    required bool useChico,
    required String projectTitle,
    required Routing routing,
    bool useMaterialUi = false,
  }) {
    final pascalProject = _pascalize(projectTitle);
    var source = _read(root, homePagePath);
    if (source == null || !source.contains(homeBegin)) {
      source = useChico
          ? freshChicoHome(projectTitle: pascalProject, routing: routing)
          : freshMaterialHome(
              projectTitle: pascalProject,
              routing: routing,
              useMaterialUi: useMaterialUi,
            );
    }

    if (routing == Routing.goRouter &&
        !source.contains("import 'package:go_router/go_router.dart';")) {
      // Anchor after Material/Chico/Flutter UI imports (incl. material_ui).
      final anchor = RegExp(
        r"import 'package:(?:flutter/|material_ui/|cupertino_ui/|chico_[^']+/)"
        r"[^']+\.dart';",
      );
      final match = anchor.firstMatch(source);
      if (match != null) {
        source = source.replaceFirst(
          match.group(0)!,
          '${match.group(0)!}\nimport \'package:go_router/go_router.dart\';',
        );
      } else {
        final firstImport = RegExp(r'^import .*;\s*$', multiLine: true);
        final first = firstImport.firstMatch(source);
        if (first != null) {
          source = source.replaceFirst(
            first.group(0)!,
            '${first.group(0)!}\nimport \'package:go_router/go_router.dart\';',
          );
        }
      }
    }

    final path = '/features/${layout.snake}';
    final open = routing == Routing.goRouter
        ? "context.go('$path')"
        : "Navigator.of(context).pushNamed('$path')";
    final entry = useChico
        ? '''
            ChicoListTile(
              title: '${layout.pascal}',
              subtitle: 'Open demo feature',
              onPressed: () => $open,
            ),'''
        : '''
            ListTile(
              title: const Text('${layout.pascal}'),
              subtitle: const Text('Open demo feature'),
              onTap: () => $open,
            ),''';

    return upsertLine(
      source,
      begin: homeBegin,
      end: homeEnd,
      entry: entry,
      identity: path,
    );
  }

  static String freshChicoHome({
    required String projectTitle,
    required Routing routing,
  }) {
    final routerImport = routing == Routing.goRouter
        ? "import 'package:go_router/go_router.dart';\n"
        : '';
    return '''
import 'package:flutter/widgets.dart';
${routerImport}import 'package:chico_kit/chico_kit.dart';

/// Example home screen.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChicoScaffold(
      bar: const ChicoBar(title: '$projectTitle'),
      body: ChicoPage(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ChicoText(
              'Welcome to $projectTitle',
              variant: ChicoTextVariant.title,
            ),
            $homeBegin
            $homeEnd
          ],
        ),
      ),
    );
  }
}
''';
  }

  static String freshMaterialHome({
    required String projectTitle,
    required Routing routing,
    bool useMaterialUi = false,
  }) {
    final routerImport = routing == Routing.goRouter
        ? "import 'package:go_router/go_router.dart';\n"
        : '';
    return '''
${UiImports.materialImport(useMaterialUi: useMaterialUi)}
$routerImport
/// Example home screen.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('$projectTitle')),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Welcome to $projectTitle'),
          ),
          $homeBegin
          $homeEnd
        ],
      ),
    );
  }
}
''';
  }

  static String upsertLine(
    String source, {
    required String begin,
    required String end,
    required String entry,
    required String identity,
  }) {
    final start = source.indexOf(begin);
    final stop = source.indexOf(end);
    if (start < 0 || stop < 0 || stop < start) {
      return source;
    }
    final innerStart = start + begin.length;
    final inner = source.substring(innerStart, stop);
    if (inner.contains(identity)) {
      return source;
    }
    final trimmed = entry.trimRight();
    final insertion = '\n$trimmed\n';
    return source.replaceRange(innerStart, stop, '$inner$insertion');
  }

  static String? _read(String root, String relative) {
    final file = File(p.join(root, relative));
    if (!file.existsSync()) return null;
    return file.readAsStringSync();
  }

  static String _pascalize(String raw) {
    final parts = raw
        .split(RegExp(r'[^A-Za-z0-9]+'))
        .where((p) => p.isNotEmpty);
    return parts.map((p) => '${p[0].toUpperCase()}${p.substring(1)}').join();
  }
}
