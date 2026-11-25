import 'dart:io';

import 'package:chico_flutter_devkit/chico_flutter_devkit.dart';
import 'package:chico_flutter_devkit/src/generators/feature/feature_generator.dart';
import 'package:chico_flutter_devkit/src/generators/feature/feature_integration.dart';
import 'package:chico_flutter_devkit/src/project/adopt_service.dart';
import 'package:chico_flutter_devkit/src/project/flutter_cli.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../support/project_fixtures.dart';

void main() {
  late Directory tempRoot;
  late Directory homeDir;
  late ConfigService configService;
  late FakeFlutterCli flutterCli;
  late AdoptService adopt;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('devkit_adopt_');
    homeDir = await Directory.systemTemp.createTemp('devkit_adopt_home_');
    configService = ConfigService(homeOverride: homeDir.path);
    flutterCli = FakeFlutterCli();
    adopt = AdoptService(configService: configService, flutterCli: flutterCli);
  });

  tearDown(() async {
    await tempRoot.delete(recursive: true);
    await homeDir.delete(recursive: true);
  });

  test('adopt writes config + anchors for empty Flutter tree', () async {
    await writeFlutterPubspec(tempRoot.path, name: 'legacy_app');
    await Directory(p.join(tempRoot.path, 'lib')).create();

    final result = await adopt.adopt(
      projectRoot: tempRoot.path,
      architecture: Architecture.clean,
      state: StateManagement.bloc,
      routing: Routing.goRouter,
      di: DependencyInjection.getIt,
    );

    expect(result.projectName, 'legacy_app');
    expect(
      File(p.join(tempRoot.path, '.chico', 'devkit.yaml')).existsSync(),
      isTrue,
    );
    expect(
      File(
        p.join(tempRoot.path, 'lib', 'core', 'routing', 'feature_routes.dart'),
      ).existsSync(),
      isTrue,
    );
    expect(
      File(
        p.join(
          tempRoot.path,
          'lib',
          'features',
          'home',
          'presentation',
          'pages',
          'home_page.dart',
        ),
      ).readAsStringSync(),
      contains(FeatureIntegration.homeBegin),
    );
    expect(
      File(
        p.join(
          tempRoot.path,
          'lib',
          'features',
          'home',
          'presentation',
          'pages',
          'home_page.dart',
        ),
      ).readAsStringSync(),
      contains("package:flutter/material.dart"),
    );
  });

  test('adopt uses material_ui Home when Flutter ≥ 3.47', () async {
    flutterCli = FakeFlutterCli(materialUiSupported: true);
    adopt = AdoptService(configService: configService, flutterCli: flutterCli);
    await writeFlutterPubspec(tempRoot.path, name: 'legacy_app');
    await Directory(p.join(tempRoot.path, 'lib')).create();

    await adopt.adopt(
      projectRoot: tempRoot.path,
      architecture: Architecture.clean,
      state: StateManagement.bloc,
      routing: Routing.goRouter,
      di: DependencyInjection.getIt,
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
    expect(home, contains("package:material_ui/material_ui.dart"));
    expect(home, isNot(contains("package:flutter/material.dart")));
    final pubspec = File(
      p.join(tempRoot.path, 'pubspec.yaml'),
    ).readAsStringSync();
    expect(pubspec, contains('material_ui:'));
    expect(pubspec, contains('cupertino_ui:'));
  });

  test('adopt refuses Home without markers', () async {
    await writeFlutterPubspec(tempRoot.path, name: 'legacy_app');
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
    await home.writeAsString('class HomePage {}');

    await expectLater(
      () => adopt.adopt(
        projectRoot: tempRoot.path,
        architecture: Architecture.clean,
        state: StateManagement.bloc,
        routing: Routing.goRouter,
        di: DependencyInjection.getIt,
      ),
      throwsA(
        isA<InvalidUsageException>().having(
          (e) => e.message,
          'message',
          contains('without DevKit anchors'),
        ),
      ),
    );
  });

  test('feature generate refuses unmarked Home', () async {
    await writeFlutterPubspec(tempRoot.path, name: 'shop_app');
    await configService.initProjectConfig(
      projectRoot: tempRoot.path,
      config: DevKitConfigDefaults.create(projectName: 'shop_app'),
      force: true,
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
    );
    await home.parent.create(recursive: true);
    await home.writeAsString('class HomePage {}');
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
List<RouteBase> get featureRoutes => [
// <devkit:feature-routes>
// </devkit:feature-routes>
];
''');

    final runner = GeneratorRunner(
      registry: GeneratorRegistry(generators: [FeatureGenerator()]),
      configService: configService,
    );
    await expectLater(
      () => runner.run(
        projectRoot: tempRoot.path,
        generatorName: 'feature',
        targetName: 'products',
        extra: {'tests': false},
      ),
      throwsA(isA<InvalidUsageException>()),
    );
  });

  test('adopt then feature generate succeeds', () async {
    await writeFlutterPubspec(tempRoot.path, name: 'legacy_app');
    await Directory(p.join(tempRoot.path, 'lib')).create();
    await adopt.adopt(
      projectRoot: tempRoot.path,
      architecture: Architecture.clean,
      state: StateManagement.bloc,
      routing: Routing.goRouter,
      di: DependencyInjection.getIt,
    );

    final runner = GeneratorRunner(
      registry: GeneratorRegistry(generators: [FeatureGenerator()]),
      configService: configService,
    );
    final result = await runner.run(
      projectRoot: tempRoot.path,
      generatorName: 'feature',
      targetName: 'products',
      extra: {'tests': false},
    );
    expect(result.writes.createdCount, greaterThan(0));
    expect(
      File(
        p.join(
          tempRoot.path,
          'lib',
          'features',
          'products',
          'domain',
          'entities',
          'products.dart',
        ),
      ).existsSync(),
      isTrue,
    );
  });
}
