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
    tempRoot = await Directory.systemTemp.createTemp('devkit_feat_tests_');
    homeDir = await Directory.systemTemp.createTemp('devkit_feat_tests_home_');
    configService = ConfigService(homeOverride: homeDir.path);
    await writeFlutterPubspec(tempRoot.path, name: 'shop_app');
    await configService.initProjectConfig(
      projectRoot: tempRoot.path,
      config: DevKitConfigDefaults.create(projectName: 'shop_app'),
      force: true,
    );
    await _seedAnchors(tempRoot.path);
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

  test('API-wired feature emits mapping + use-case load/error tests', () async {
    final runner = GeneratorRunner(
      registry: GeneratorRegistry(generators: [FeatureGenerator()]),
      configService: configService,
    );

    await runner.run(
      projectRoot: tempRoot.path,
      generatorName: 'feature',
      targetName: 'products',
      extra: {
        'spec': fixtureSpec,
        'apiName': 'shop',
        'pagination': true,
        'search': true,
        'tests': true,
      },
    );

    final mapping = File(
      p.join(
        tempRoot.path,
        'test',
        'features',
        'products',
        'products_remote_mapping_test.dart',
      ),
    );
    expect(mapping.existsSync(), isTrue);
    final mappingSrc = mapping.readAsStringSync();
    expect(mappingSrc, contains('mapDto'));
    expect(mappingSrc, contains('expect(model.id'));

    final useCase = File(
      p.join(
        tempRoot.path,
        'test',
        'features',
        'products',
        'products_usecase_test.dart',
      ),
    );
    expect(useCase.existsSync(), isTrue);
    final useCaseSrc = useCase.readAsStringSync();
    expect(useCaseSrc, contains('GetProductsList returns repository items'));
    expect(useCaseSrc, contains('surfaces repository errors'));
    expect(useCaseSrc, contains('_FakeProductsRepository'));
  });
}

Future<void> _seedAnchors(String root) async {
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
