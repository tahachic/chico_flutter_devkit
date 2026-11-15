import 'dart:io';

import 'package:path/path.dart' as p;

import '../../config/models.dart';
import '../../fs/write_plan.dart';
import '../context.dart';
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
  static const homeBegin = '// <devkit:home-features>';
  static const homeEnd = '// </devkit:home-features>';

  static const featureRoutesPath = 'lib/core/routing/feature_routes.dart';
  static const featureRegistrationsPath =
      'lib/core/di/feature_registrations.dart';
  static const homePagePath =
      'lib/features/home/presentation/pages/home_page.dart';

  /// Planned writes that upsert this feature into create-time registries.
  static List<PlannedFileWrite> planHooks({
    required GenerationContext context,
    required FeatureLayout layout,
    required bool includeRemote,
    required bool includeLocal,
  }) {
    final project = context.config.project.name;
    final useChico =
        context.config.chico.ui.enabled ||
        context.config.chico.kit.enabled ||
        context.config.chico.services.enabled;
    final writes = <PlannedFileWrite>[];

    if (context.config.flutter.routing == Routing.goRouter) {
      writes.add(
        PlannedFileWrite(
          relativePath: featureRoutesPath,
          content: upsertFeatureRoutes(
            root: context.projectRoot,
            project: project,
            layout: layout,
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
            projectTitle: context.config.project.name,
          ),
          mode: FileWriteMode.overwrite,
        ),
      );
    }

    if (context.config.flutter.dependencyInjection ==
        DependencyInjection.getIt) {
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
    }

    return writes;
  }

  static String upsertFeatureRoutes({
    required String root,
    required String project,
    required FeatureLayout layout,
  }) {
    final pageImport = layout.packageImport(project, layout.page);
    final routeEntry =
        '''
  GoRoute(
    path: '/features/${layout.snake}',
    name: '${layout.snake}',
    builder: (context, state) => const ${layout.pascal}Page(),
  ),''';

    var source = _read(root, featureRoutesPath) ?? freshFeatureRoutes();
    if (!source.contains(routeImportsBegin) || !source.contains(routesBegin)) {
      source = freshFeatureRoutes();
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
      identity: '/features/${layout.snake}',
    );
    return source;
  }

  static String freshFeatureRoutes() =>
      '''
import 'package:go_router/go_router.dart';

$routeImportsBegin
$routeImportsEnd

/// GoRoutes appended by `devkit generate feature`.
List<RouteBase> get featureRoutes => [
$routesBegin
$routesEnd
];
''';

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

  static String upsertHomeLink({
    required String root,
    required FeatureLayout layout,
    required bool useChico,
    required String projectTitle,
  }) {
    final pascalProject = _pascalize(projectTitle);
    var source = _read(root, homePagePath);
    if (source == null || !source.contains(homeBegin)) {
      source = useChico
          ? freshChicoHome(projectTitle: pascalProject)
          : freshMaterialHome(projectTitle: pascalProject);
    }

    if (!source.contains("import 'package:go_router/go_router.dart';")) {
      final flutterImport = RegExp(r"import 'package:flutter/[^']+\.dart';");
      final match = flutterImport.firstMatch(source);
      if (match != null) {
        source = source.replaceFirst(
          match.group(0)!,
          "${match.group(0)!}\nimport 'package:go_router/go_router.dart';",
        );
      }
    }

    final entry = useChico
        ? '''
            ChicoListTile(
              title: '${layout.pascal}',
              subtitle: 'Open demo feature',
              onPressed: () => context.go('/features/${layout.snake}'),
            ),'''
        : '''
            ListTile(
              title: const Text('${layout.pascal}'),
              subtitle: const Text('Open demo feature'),
              onTap: () => context.go('/features/${layout.snake}'),
            ),''';

    return upsertLine(
      source,
      begin: homeBegin,
      end: homeEnd,
      entry: entry,
      identity: '/features/${layout.snake}',
    );
  }

  static String freshChicoHome({required String projectTitle}) =>
      '''
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:chico_kit/chico_kit.dart';

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

  static String freshMaterialHome({required String projectTitle}) =>
      '''
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
