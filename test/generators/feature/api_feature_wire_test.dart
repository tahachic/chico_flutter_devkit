import 'dart:io';

import 'package:chico_flutter_devkit/chico_flutter_devkit.dart';
import 'package:chico_flutter_devkit/src/generators/api/api_generator.dart';
import 'package:chico_flutter_devkit/src/generators/feature/api_feature_wire.dart';
import 'package:chico_flutter_devkit/src/generators/feature/feature_generator.dart';
import 'package:chico_flutter_devkit/src/generators/shared/field_spec.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../../support/project_fixtures.dart';

void main() {
  late Directory tempRoot;
  late Directory homeDir;
  late ConfigService configService;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('devkit_api_wire_');
    homeDir = await Directory.systemTemp.createTemp('devkit_api_wire_home_');
    configService = ConfigService(homeOverride: homeDir.path);
  });

  tearDown(() async {
    await tempRoot.delete(recursive: true);
    await homeDir.delete(recursive: true);
  });

  Future<void> prepareProject() async {
    await writeFlutterPubspec(tempRoot.path, name: 'shop_app');
    await configService.initProjectConfig(
      projectRoot: tempRoot.path,
      config: DevKitConfigDefaults.create(projectName: 'shop_app'),
      force: true,
    );
  }

  Future<void> generateShopApi() async {
    final fixture = p.join(
      Directory.current.path,
      'test',
      'fixtures',
      'openapi',
      'shop_api.yaml',
    );
    final runner = GeneratorRunner(
      registry: GeneratorRegistry(generators: [ApiGenerator()]),
      configService: configService,
    );
    await runner.run(
      projectRoot: tempRoot.path,
      generatorName: 'api',
      targetName: 'shop',
      extra: {'spec': fixture},
    );
  }

  test('resolve maps listProducts and shared fields', () async {
    await prepareProject();
    await generateShopApi();

    final plan = ApiFeatureWire.resolve(
      projectRoot: tempRoot.path,
      apiName: 'shop',
      featureSnake: 'products',
      featureFields: const [
        FieldSpec(name: 'id', type: 'String'),
        FieldSpec(name: 'name', type: 'String'),
        FieldSpec(name: 'description', type: 'String', isNullable: true),
      ],
      needCrud: false,
      needPagination: true,
      needSearch: true,
    );

    expect(plan.clientPascal, 'ShopApi');
    expect(plan.listMethod.name, 'listProducts');
    expect(plan.itemType, 'Product');
    expect(plan.listHasPage, isTrue);
    expect(plan.listHasQuery, isTrue);
    expect(
      plan.mappings
          .where((m) => m.featureField.name == 'description')
          .single
          .expression,
      'null',
    );
  });

  test('missing client fails closed', () async {
    await prepareProject();
    expect(
      () => ApiFeatureWire.resolve(
        projectRoot: tempRoot.path,
        apiName: 'shop',
        featureSnake: 'products',
        featureFields: const [FieldSpec(name: 'id', type: 'String')],
        needCrud: false,
        needPagination: false,
        needSearch: false,
      ),
      throwsA(isA<InvalidUsageException>()),
    );
  });

  test('unmappable required field fails closed', () async {
    await prepareProject();
    await generateShopApi();
    expect(
      () => ApiFeatureWire.resolve(
        projectRoot: tempRoot.path,
        apiName: 'shop',
        featureSnake: 'products',
        featureFields: const [
          FieldSpec(name: 'id', type: 'String'),
          FieldSpec(name: 'skuCode', type: 'String'),
        ],
        needCrud: false,
        needPagination: false,
        needSearch: false,
      ),
      throwsA(
        isA<InvalidUsageException>().having(
          (e) => e.message,
          'message',
          contains('skuCode'),
        ),
      ),
    );
  });

  test('feature --from-api writes API remote datasource and DI', () async {
    await prepareProject();
    await generateShopApi();

    // Minimal DI registration file so upsert has anchors.
    final regs = File(
      p.join(tempRoot.path, 'lib', 'core', 'di', 'feature_registrations.dart'),
    );
    await regs.parent.create(recursive: true);
    await regs.writeAsString('''
import 'package:get_it/get_it.dart';

// <devkit:feature-di-imports>
// </devkit:feature-di-imports>

void registerFeatures(GetIt getIt) {
// <devkit:feature-registrations>
// </devkit:feature-registrations>
}
''');
    final routes = File(
      p.join(tempRoot.path, 'lib', 'core', 'routing', 'feature_routes.dart'),
    );
    await routes.parent.create(recursive: true);
    await routes.writeAsString('''
import 'package:go_router/go_router.dart';
// <devkit:feature-route-imports>
// </devkit:feature-route-imports>
List<RouteBase> buildFeatureRoutes() => [
// <devkit:feature-routes>
// </devkit:feature-routes>
];
''');
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
    );
    await home.parent.create(recursive: true);
    await home.writeAsString('''
import 'package:flutter/material.dart';
class HomePage extends StatelessWidget {
  const HomePage({super.key});
  @override
  Widget build(BuildContext context) {
    return ListView(children: [
// <devkit:home-features>
// </devkit:home-features>
    ]);
  }
}
''');

    final runner = GeneratorRunner(
      registry: GeneratorRegistry(generators: [FeatureGenerator()]),
      configService: configService,
    );

    final result = await runner.run(
      projectRoot: tempRoot.path,
      generatorName: 'feature',
      targetName: 'products',
      extra: {
        'fromApi': 'shop',
        'pagination': true,
        'search': true,
        'tests': false,
      },
    );

    expect(result.message, contains('ShopApi'));
    final remote = File(
      p.join(
        tempRoot.path,
        'lib',
        'features',
        'products',
        'data',
        'datasources',
        'products_remote_datasource.dart',
      ),
    ).readAsStringSync();
    expect(remote, contains('ShopApi'));
    expect(remote, contains('listProducts'));
    expect(remote, contains('_mapDto'));
    expect(remote, isNot(contains('Demo in-memory')));

    final di = regs.readAsStringSync();
    expect(di, contains('ShopApi'));
    expect(di, contains('ProductsRemoteDataSource(api: getIt())'));

    expect(
      File(
        p.join(tempRoot.path, '.chico', 'generate_manifest.yaml'),
      ).existsSync(),
      isTrue,
    );
  });

  test('feature without --from-api still uses in-memory remote', () async {
    await prepareProject();
    final regs = File(
      p.join(tempRoot.path, 'lib', 'core', 'di', 'feature_registrations.dart'),
    );
    await regs.parent.create(recursive: true);
    await regs.writeAsString('''
import 'package:get_it/get_it.dart';
// <devkit:feature-di-imports>
// </devkit:feature-di-imports>
void registerFeatures(GetIt getIt) {
// <devkit:feature-registrations>
// </devkit:feature-registrations>
}
''');
    final routes = File(
      p.join(tempRoot.path, 'lib', 'core', 'routing', 'feature_routes.dart'),
    );
    await routes.parent.create(recursive: true);
    await routes.writeAsString('''
import 'package:go_router/go_router.dart';
// <devkit:feature-route-imports>
// </devkit:feature-route-imports>
List<RouteBase> buildFeatureRoutes() => [
// <devkit:feature-routes>
// </devkit:feature-routes>
];
''');
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
    );
    await home.parent.create(recursive: true);
    await home.writeAsString('''
import 'package:flutter/material.dart';
class HomePage extends StatelessWidget {
  const HomePage({super.key});
  @override
  Widget build(BuildContext context) {
    return ListView(children: [
// <devkit:home-features>
// </devkit:home-features>
    ]);
  }
}
''');

    final runner = GeneratorRunner(
      registry: GeneratorRegistry(generators: [FeatureGenerator()]),
      configService: configService,
    );
    await runner.run(
      projectRoot: tempRoot.path,
      generatorName: 'feature',
      targetName: 'catalog',
      extra: {'tests': false},
    );

    final remote = File(
      p.join(
        tempRoot.path,
        'lib',
        'features',
        'catalog',
        'data',
        'datasources',
        'catalog_remote_datasource.dart',
      ),
    ).readAsStringSync();
    expect(remote, contains('demo in-memory'));
  });

  test('missing API client does not write feature files', () async {
    await prepareProject();
    final runner = GeneratorRunner(
      registry: GeneratorRegistry(generators: [FeatureGenerator()]),
      configService: configService,
    );
    await expectLater(
      () => runner.run(
        projectRoot: tempRoot.path,
        generatorName: 'feature',
        targetName: 'products',
        extra: {'fromApi': 'missing', 'tests': false},
      ),
      throwsA(isA<InvalidUsageException>()),
    );
    expect(
      Directory(
        p.join(tempRoot.path, 'lib', 'features', 'products'),
      ).existsSync(),
      isFalse,
    );
  });
}
