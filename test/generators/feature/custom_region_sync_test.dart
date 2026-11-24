import 'dart:io';

import 'package:chico_flutter_devkit/chico_flutter_devkit.dart';
import 'package:chico_flutter_devkit/src/fs/custom_regions.dart';
import 'package:chico_flutter_devkit/src/generators/feature/feature_generator.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../../support/project_fixtures.dart';

void main() {
  late Directory tempRoot;
  late Directory homeDir;
  late ConfigService configService;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('devkit_region_sync_');
    homeDir = await Directory.systemTemp.createTemp('devkit_region_home_');
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

  Future<GeneratorRunner> runner() async => GeneratorRunner(
    registry: GeneratorRegistry(generators: [FeatureGenerator()]),
    configService: configService,
  );

  test('custom region body survives --sync regenerate', () async {
    final r = await runner();
    await r.run(
      projectRoot: tempRoot.path,
      generatorName: 'feature',
      targetName: 'products',
      extra: {'spec': fixtureSpec, 'apiName': 'shop', 'tests': false},
    );

    final remotePath = p.join(
      tempRoot.path,
      'lib',
      'features',
      'products',
      'data',
      'datasources',
      'products_remote_datasource.dart',
    );
    final original = File(remotePath).readAsStringSync();
    expect(original, contains('devkit:custom id="remote.map"'));

    final edited = original.replaceFirst(
      '// Customize DTO → model mapping\n',
      '    // KEEP_ME_CUSTOM\n',
    );
    await File(remotePath).writeAsString(edited);

    await r.run(
      projectRoot: tempRoot.path,
      generatorName: 'feature',
      targetName: 'products',
      sync: true,
      extra: {
        'spec': fixtureSpec,
        'apiName': 'shop',
        'tests': false,
        'force': false,
      },
    );

    final after = File(remotePath).readAsStringSync();
    expect(after, contains('KEEP_ME_CUSTOM'));
    expect(
      CustomRegions.extract(after)['remote.map'],
      contains('KEEP_ME_CUSTOM'),
    );
  });

  test('edits outside custom region still refuse --sync', () async {
    final r = await runner();
    await r.run(
      projectRoot: tempRoot.path,
      generatorName: 'feature',
      targetName: 'products',
      extra: {'spec': fixtureSpec, 'apiName': 'shop', 'tests': false},
    );

    final remotePath = p.join(
      tempRoot.path,
      'lib',
      'features',
      'products',
      'data',
      'datasources',
      'products_remote_datasource.dart',
    );
    final original = File(remotePath).readAsStringSync();
    await File(remotePath).writeAsString('$original\n// outside region\n');

    await expectLater(
      () => r.run(
        projectRoot: tempRoot.path,
        generatorName: 'feature',
        targetName: 'products',
        sync: true,
        extra: {'spec': fixtureSpec, 'apiName': 'shop', 'tests': false},
      ),
      throwsA(
        isA<ExecutionException>().having(
          (e) => e.message,
          'message',
          contains('user-edited'),
        ),
      ),
    );
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
