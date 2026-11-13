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
