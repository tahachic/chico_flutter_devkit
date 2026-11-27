import 'dart:io';

import 'package:chico_flutter_devkit/chico_flutter_devkit.dart';
import 'package:chico_flutter_devkit/src/generators/feature/feature_generator.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../../support/project_fixtures.dart';

void main() {
  late Directory tempRoot;
  late Directory homeDir;
  late ConfigService configService;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('devkit_feature_');
    homeDir = await Directory.systemTemp.createTemp('devkit_feature_home_');
    configService = ConfigService(homeOverride: homeDir.path);
  });

  tearDown(() async {
    await tempRoot.delete(recursive: true);
    await homeDir.delete(recursive: true);
  });

  Future<GeneratorRunner> buildRunner(DevKitConfig config) async {
    await writeFlutterPubspec(
      tempRoot.path,
      name: config.project.name,
      chicoUi: config.chico.ui.enabled,
      chicoKit: config.chico.kit.enabled,
      chicoServices: config.chico.services.enabled,
    );
    await configService.initProjectConfig(
      projectRoot: tempRoot.path,
      config: config,
      force: true,
    );
    return GeneratorRunner(
      registry: GeneratorRegistry(generators: [FeatureGenerator()]),
      configService: configService,
    );
  }

  test('generates clean architecture feature with bloc', () async {
    final runner = await buildRunner(
      DevKitConfigDefaults.create(projectName: 'shop_app'),
    );

    final result = await runner.run(
      projectRoot: tempRoot.path,
      generatorName: 'feature',
      targetName: 'products',
      extra: {
        'architecture': 'clean',
        'crud': true,
        'pagination': true,
        'search': true,
        'local': true,
        'tests': true,
      },
    );

    expect(result.writes.createdCount, greaterThan(8));

    final root = p.join(tempRoot.path, 'lib', 'features', 'products');
    expect(
      File(p.join(root, 'domain', 'entities', 'products.dart')).existsSync(),
      isTrue,
    );
    expect(
      File(
        p.join(root, 'domain', 'repositories', 'products_repository.dart'),
      ).existsSync(),
      isTrue,
    );
    expect(
      File(
        p.join(root, 'data', 'repositories', 'products_repository_impl.dart'),
      ).existsSync(),
      isTrue,
    );
    expect(
      File(
        p.join(root, 'presentation', 'bloc', 'products_bloc.dart'),
      ).existsSync(),
      isTrue,
    );
    expect(
      File(
        p.join(root, 'presentation', 'pages', 'products_page.dart'),
      ).existsSync(),
      isTrue,
    );

    final repo = File(
      p.join(root, 'domain', 'repositories', 'products_repository.dart'),
    ).readAsStringSync();
    expect(repo, contains('fetchPage'));
    expect(repo, contains('search'));
    expect(repo, contains('create'));

    final useCases = File(
      p.join(root, 'domain', 'usecases', 'get_products_list.dart'),
    ).readAsStringSync();
    expect(useCases, contains('class SearchProducts'));
    expect(useCases, contains('class GetProductsPage'));

    final events = File(
      p.join(root, 'presentation', 'bloc', 'products_event.dart'),
    ).readAsStringSync();
    expect(events, contains('ProductsSearched'));
    expect(events, contains('ProductsPageRequested'));

    final entityTest = File(
      p.join(
        tempRoot.path,
        'test',
        'features',
        'products',
        'products_entity_test.dart',
      ),
    ).readAsStringSync();
    expect(
      entityTest,
      contains("import 'package:flutter_test/flutter_test.dart';"),
    );
    expect(entityTest, isNot(contains("import 'package:test/test.dart';")));

    final remote = File(
      p.join(root, 'data', 'datasources', 'products_remote_datasource.dart'),
    ).readAsStringSync();
    expect(remote, contains('_items'));
    expect(remote, contains('Name 1'));
    expect(remote, contains('fetchAll'));

    final page = File(
      p.join(root, 'presentation', 'pages', 'products_page.dart'),
    ).readAsStringSync();
    expect(page, contains('BlocProvider'));
    expect(page, contains('ProductsStarted'));
    expect(page, contains('ProductsListTile'));
    expect(page, contains('ProductsSearched'));
    expect(page, contains('ProductsPageRequested'));
    expect(page, isNot(contains('Wire to repository.search')));
    expect(page, contains('getIt<GetProductsList>()'));
    expect(page, isNot(contains('TODO(devkit)')));

    final regs = File(
      p.join(tempRoot.path, 'lib', 'core', 'di', 'feature_registrations.dart'),
    ).readAsStringSync();
    expect(regs, contains('ProductsRepository'));
    expect(regs, contains('GetProductsList'));

    final routes = File(
      p.join(tempRoot.path, 'lib', 'core', 'routing', 'feature_routes.dart'),
    ).readAsStringSync();
    expect(routes, contains('/features/products'));
    expect(routes, contains('ProductsPage'));
  });

  test('riverpod feature has no UnimplementedError', () async {
    final base = DevKitConfigDefaults.create(projectName: 'shop_app');
    final runner = await buildRunner(
      base.copyWith(
        flutter: base.flutter.copyWith(
          stateManagement: StateManagement.riverpod,
        ),
      ),
    );

    await Directory(
      p.join(tempRoot.path, 'lib', 'core', 'routing'),
    ).create(recursive: true);
    await File(
      p.join(tempRoot.path, 'lib', 'core', 'routing', 'feature_routes.dart'),
    ).writeAsString('''
import 'package:go_router/go_router.dart';
// <devkit:feature-route-imports>
// </devkit:feature-route-imports>
List<RouteBase> get featureRoutes => [
  // <devkit:feature-routes>
  // </devkit:feature-routes>
];
''');
    await Directory(
      p.join(tempRoot.path, 'lib', 'features', 'home', 'presentation', 'pages'),
    ).create(recursive: true);
    await File(
      p.join(
        tempRoot.path,
        'lib',
        'features',
        'home',
        'presentation',
        'pages',
        'home_page.dart',
      ),
    ).writeAsString('''
import 'package:flutter/material.dart';
class HomePage extends StatelessWidget {
  const HomePage({super.key});
  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Text('Welcome'));
    // <devkit:home-features>
    // </devkit:home-features>
  }
}
''');

    await runner.run(
      projectRoot: tempRoot.path,
      generatorName: 'feature',
      targetName: 'orders',
      extra: {'tests': false, 'remote': true},
    );

    final providers = File(
      p.join(
        tempRoot.path,
        'lib',
        'features',
        'orders',
        'presentation',
        'providers',
        'orders_providers.dart',
      ),
    ).readAsStringSync();
    expect(providers, isNot(contains('UnimplementedError')));
    expect(providers, contains('OrdersRepositoryImpl'));

    final page = File(
      p.join(
        tempRoot.path,
        'lib',
        'features',
        'orders',
        'presentation',
        'pages',
        'orders_page.dart',
      ),
    ).readAsStringSync();
    expect(page, contains('ConsumerWidget'));
    expect(page, contains('ordersListProvider'));
  });

  test('generates layered architecture feature with riverpod', () async {
    final base = DevKitConfigDefaults.create(projectName: 'shop_app');
    final runner = await buildRunner(
      base.copyWith(
        project: base.project.copyWith(architecture: Architecture.layered),
        flutter: base.flutter.copyWith(
          stateManagement: StateManagement.riverpod,
        ),
        features: base.features.copyWith(
          defaultArchitecture: Architecture.layered,
        ),
      ),
    );

    final result = await runner.run(
      projectRoot: tempRoot.path,
      generatorName: 'feature',
      targetName: 'orders',
      extra: {'tests': false, 'remote': true},
    );

    expect(result.writes.createdCount, greaterThan(5));
    expect(
      File(
        p.join(tempRoot.path, 'lib', 'domain', 'entities', 'orders.dart'),
      ).existsSync(),
      isTrue,
    );
    expect(
      File(
        p.join(
          tempRoot.path,
          'lib',
          'presentation',
          'features',
          'orders',
          'providers',
          'orders_providers.dart',
        ),
      ).existsSync(),
      isTrue,
    );
  });

  test('go_router home link adds import when home uses material_ui', () async {
    final base = DevKitConfigDefaults.create(projectName: 'shop_app');
    final runner = await buildRunner(base);

    await Directory(
      p.join(tempRoot.path, 'lib', 'core', 'routing'),
    ).create(recursive: true);
    await File(
      p.join(tempRoot.path, 'lib', 'core', 'routing', 'feature_routes.dart'),
    ).writeAsString('''
import 'package:go_router/go_router.dart';
// <devkit:feature-route-imports>
// </devkit:feature-route-imports>
List<RouteBase> get featureRoutes => [
  // <devkit:feature-routes>
  // </devkit:feature-routes>
];
''');
    await Directory(
      p.join(tempRoot.path, 'lib', 'features', 'home', 'presentation', 'pages'),
    ).create(recursive: true);
    await File(
      p.join(
        tempRoot.path,
        'lib',
        'features',
        'home',
        'presentation',
        'pages',
        'home_page.dart',
      ),
    ).writeAsString('''
import 'package:material_ui/material_ui.dart';
class HomePage extends StatelessWidget {
  const HomePage({super.key});
  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Text('Welcome'));
    // <devkit:home-features>
    // </devkit:home-features>
  }
}
''');
    // Mark project as material_ui so generators prefer that import path.
    await File(p.join(tempRoot.path, 'pubspec.yaml')).writeAsString('''
name: shop_app
dependencies:
  flutter:
    sdk: flutter
  material_ui: ^1.0.0
  go_router: ^14.0.0
''');

    await runner.run(
      projectRoot: tempRoot.path,
      generatorName: 'feature',
      targetName: 'products',
      extra: {'tests': false, 'remote': true},
    );

    final home = File(
      p.join(
        tempRoot.path,
        'lib',
        'features',
        'home',
        'presentation',
        'pages',
        'home_page.dart',
      ),
    ).readAsStringSync();
    expect(home, contains("import 'package:go_router/go_router.dart';"));
    expect(home, contains("context.go('/features/products')"));
  });

  test(
    'navigator routing registers named route and pushNamed home link',
    () async {
      final base = DevKitConfigDefaults.create(projectName: 'shop_app');
      final runner = await buildRunner(
        base.copyWith(
          flutter: base.flutter.copyWith(routing: Routing.navigator),
        ),
      );

      await Directory(
        p.join(tempRoot.path, 'lib', 'core', 'routing'),
      ).create(recursive: true);
      await File(
        p.join(tempRoot.path, 'lib', 'core', 'routing', 'feature_routes.dart'),
      ).writeAsString('''
import 'package:flutter/widgets.dart';
// <devkit:feature-route-imports>
// </devkit:feature-route-imports>
Map<String, WidgetBuilder> get featureRoutes => {
  // <devkit:feature-routes>
  // </devkit:feature-routes>
};
''');
      await Directory(
        p.join(
          tempRoot.path,
          'lib',
          'features',
          'home',
          'presentation',
          'pages',
        ),
      ).create(recursive: true);
      await File(
        p.join(
          tempRoot.path,
          'lib',
          'features',
          'home',
          'presentation',
          'pages',
          'home_page.dart',
        ),
      ).writeAsString('''
import 'package:flutter/material.dart';
class HomePage extends StatelessWidget {
  const HomePage({super.key});
  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Text('Welcome'));
    // <devkit:home-features>
    // </devkit:home-features>
  }
}
''');

      await runner.run(
        projectRoot: tempRoot.path,
        generatorName: 'feature',
        targetName: 'tickets',
        extra: {'tests': false, 'remote': true},
      );

      final routes = File(
        p.join(tempRoot.path, 'lib', 'core', 'routing', 'feature_routes.dart'),
      ).readAsStringSync();
      expect(
        routes,
        contains("'/features/tickets': (_) => const TicketsPage()"),
      );
      expect(routes, isNot(contains('GoRoute')));

      final home = File(
        p.join(
          tempRoot.path,
          'lib',
          'features',
          'home',
          'presentation',
          'pages',
          'home_page.dart',
        ),
      ).readAsStringSync();
      expect(
        home,
        contains("Navigator.of(context).pushNamed('/features/tickets')"),
      );
    },
  );

  test('manual DI feature wires FeatureFactories', () async {
    final base = DevKitConfigDefaults.create(projectName: 'shop_app');
    final runner = await buildRunner(
      base.copyWith(
        flutter: base.flutter.copyWith(
          dependencyInjection: DependencyInjection.manual,
        ),
      ),
    );

    await Directory(
      p.join(tempRoot.path, 'lib', 'core', 'di'),
    ).create(recursive: true);
    await File(
      p.join(tempRoot.path, 'lib', 'core', 'di', 'feature_factories.dart'),
    ).writeAsString('''
// <devkit:feature-factory-imports>
// </devkit:feature-factory-imports>
abstract final class FeatureFactories {
  // <devkit:feature-factories>
  // </devkit:feature-factories>
}
''');

    await runner.run(
      projectRoot: tempRoot.path,
      generatorName: 'feature',
      targetName: 'catalog',
      extra: {'tests': false, 'remote': true},
    );

    final page = File(
      p.join(
        tempRoot.path,
        'lib',
        'features',
        'catalog',
        'presentation',
        'pages',
        'catalog_page.dart',
      ),
    ).readAsStringSync();
    expect(page, contains('FeatureFactories.catalogList()'));

    final factories = File(
      p.join(tempRoot.path, 'lib', 'core', 'di', 'feature_factories.dart'),
    ).readAsStringSync();
    expect(factories, contains('static GetCatalogList catalogList()'));
  });

  test('riverpod DI exports feature providers barrel', () async {
    final base = DevKitConfigDefaults.create(projectName: 'shop_app');
    final runner = await buildRunner(
      base.copyWith(
        flutter: base.flutter.copyWith(
          stateManagement: StateManagement.riverpod,
          dependencyInjection: DependencyInjection.riverpod,
        ),
      ),
    );

    await Directory(
      p.join(tempRoot.path, 'lib', 'core', 'di'),
    ).create(recursive: true);
    await File(
      p.join(tempRoot.path, 'lib', 'core', 'di', 'feature_providers.dart'),
    ).writeAsString('''
// <devkit:feature-provider-exports>
// </devkit:feature-provider-exports>
''');

    await runner.run(
      projectRoot: tempRoot.path,
      generatorName: 'feature',
      targetName: 'inbox',
      extra: {'tests': false, 'remote': true},
    );

    final barrel = File(
      p.join(tempRoot.path, 'lib', 'core', 'di', 'feature_providers.dart'),
    ).readAsStringSync();
    expect(barrel, contains('inbox_providers.dart'));
  });

  test('dry-run lists planned feature files', () async {
    final runner = await buildRunner(
      DevKitConfigDefaults.create(projectName: 'shop_app'),
    );
    final result = await runner.run(
      projectRoot: tempRoot.path,
      generatorName: 'feature',
      targetName: 'cart',
      dryRun: true,
      extra: {'tests': false},
    );

    expect(result.isDryRun, isTrue);
    expect(result.plannedPaths, isNotEmpty);
    expect(
      Directory(p.join(tempRoot.path, 'lib', 'features', 'cart')).existsSync(),
      isFalse,
    );
  });
}
