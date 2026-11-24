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
    tempRoot = await Directory.systemTemp.createTemp('devkit_from_spec_');
    homeDir = await Directory.systemTemp.createTemp('devkit_from_spec_home_');
    configService = ConfigService(homeOverride: homeDir.path);
    await writeFlutterPubspec(tempRoot.path, name: 'shop_app');
    await configService.initProjectConfig(
      projectRoot: tempRoot.path,
      config: DevKitConfigDefaults.create(projectName: 'shop_app'),
      force: true,
    );
    await _seedProjectAnchors(tempRoot.path);
  });

  tearDown(() async {
    await tempRoot.delete(recursive: true);
    await homeDir.delete(recursive: true);
  });

  final fixtureSpec = p.join(
    Directory.current.path,
    'test',
    'fixtures',
    'openapi',
    'shop_api.yaml',
  );

  Future<GeneratorRunner> runner() async {
    return GeneratorRunner(
      registry: GeneratorRegistry(generators: [FeatureGenerator()]),
      configService: configService,
    );
  }

  test(
    'feature --spec generates API client and wired remote datasource',
    () async {
      final result = await (await runner()).run(
        projectRoot: tempRoot.path,
        generatorName: 'feature',
        targetName: 'products',
        extra: {
          'spec': fixtureSpec,
          'apiName': 'shop',
          'pagination': true,
          'search': true,
          'tests': false,
        },
      );

      expect(result.message, contains('ShopApi'));
      expect(
        File(
          p.join(
            tempRoot.path,
            'lib',
            'api',
            'shop',
            'generated',
            'client.dart',
          ),
        ).existsSync(),
        isTrue,
      );
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
      expect(remote, contains('listProducts'));
      expect(remote, isNot(contains('demo in-memory')));
    },
  );

  test('feature --spec and --from-api together fails closed', () async {
    await expectLater(
      () => runner().then(
        (r) => r.run(
          projectRoot: tempRoot.path,
          generatorName: 'feature',
          targetName: 'products',
          extra: {'spec': fixtureSpec, 'fromApi': 'shop', 'tests': false},
        ),
      ),
      throwsA(
        isA<InvalidUsageException>().having(
          (InvalidUsageException e) => e.message,
          'message',
          contains('either --spec or --from-api'),
        ),
      ),
    );
    expect(
      Directory(p.join(tempRoot.path, 'lib', 'api')).existsSync(),
      isFalse,
    );
  });

  test('feature --spec with bad OpenAPI fails before writes', () async {
    final bad = File(p.join(tempRoot.path, 'bad.yaml'));
    await bad.writeAsString('''
openapi: 3.0.3
info: { title: Bad, version: 1.0.0 }
paths:
  /x:
    get:
      responses:
        '200':
          description: OK
          content:
            application/json:
              schema:
                oneOf:
                  - { type: string }
                  - { type: integer }
''');
    await expectLater(
      () => runner().then(
        (r) => r.run(
          projectRoot: tempRoot.path,
          generatorName: 'feature',
          targetName: 'products',
          extra: {'spec': bad.path, 'tests': false},
        ),
      ),
      throwsA(isA<DevKitException>()),
    );
    expect(
      Directory(
        p.join(tempRoot.path, 'lib', 'features', 'products'),
      ).existsSync(),
      isFalse,
    );
  });
}

Future<void> _seedProjectAnchors(String root) async {
  final regs = File(
    p.join(root, 'lib', 'core', 'di', 'feature_registrations.dart'),
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
    p.join(root, 'lib', 'core', 'routing', 'feature_routes.dart'),
  );
  await routes.parent.create(recursive: true);
  await routes.writeAsString('''
import 'package:go_router/go_router.dart';
// <devkit:feature-route-imports>
// </devkit:feature-route-imports>
List<RouteBase> get featureRoutes => [
// <devkit:feature-routes>
// </devkit:feature-routes>
];
''');
  final home = File(
    p.join(
      root,
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
}
