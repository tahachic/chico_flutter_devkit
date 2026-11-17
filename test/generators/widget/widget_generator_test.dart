import 'dart:io';

import 'package:chico_flutter_devkit/chico_flutter_devkit.dart';
import 'package:chico_flutter_devkit/src/generators/widget/widget_generator.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../../support/project_fixtures.dart';

void main() {
  late Directory tempRoot;
  late Directory homeDir;
  late GeneratorRunner runner;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('devkit_widget_');
    homeDir = await Directory.systemTemp.createTemp('devkit_widget_home_');
    final configService = ConfigService(homeOverride: homeDir.path);
    await writeFlutterPubspec(tempRoot.path, chicoUi: true, chicoKit: true);
    await configService.initProjectConfig(
      projectRoot: tempRoot.path,
      config: chicoEnabledConfig(projectName: 'shop_app'),
    );
    runner = GeneratorRunner(
      registry: GeneratorRegistry(generators: [WidgetGenerator()]),
      configService: configService,
    );
  });

  tearDown(() async {
    await tempRoot.delete(recursive: true);
    await homeDir.delete(recursive: true);
  });

  test('generates shared chico widget', () async {
    final result = await runner.run(
      projectRoot: tempRoot.path,
      generatorName: 'widget',
      targetName: 'ProductCard',
      extra: {'tests': false},
    );

    expect(result.writes.createdCount, 1);
    final source = File(
      p.join(tempRoot.path, 'lib', 'widgets', 'product_card.dart'),
    ).readAsStringSync();
    expect(source, contains('class ProductCard'));
    expect(source, contains('ChicoListTile'));
  });

  test('generates feature-local widget', () async {
    await runner.run(
      projectRoot: tempRoot.path,
      generatorName: 'widget',
      targetName: 'ProductCard',
      extra: {'feature': 'products', 'tests': false},
    );

    expect(
      File(
        p.join(
          tempRoot.path,
          'lib',
          'features',
          'products',
          'presentation',
          'widgets',
          'product_card.dart',
        ),
      ).existsSync(),
      isTrue,
    );
  });

  test('chico widget test imports ChicoApp package', () async {
    final result = await runner.run(
      projectRoot: tempRoot.path,
      generatorName: 'widget',
      targetName: 'OfferBanner',
      extra: {'tests': true},
    );

    expect(result.writes.createdCount, 2);
    final testSource = File(
      p.join(tempRoot.path, 'test', 'widgets', 'offer_banner_test.dart'),
    ).readAsStringSync();
    expect(testSource, contains("import 'package:chico_kit/chico_kit.dart';"));
    expect(testSource, contains('ChicoApp('));
  });
}
