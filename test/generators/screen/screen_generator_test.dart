import 'dart:io';

import 'package:chico_flutter_devkit/chico_flutter_devkit.dart';
import 'package:chico_flutter_devkit/src/generators/screen/screen_generator.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../../support/project_fixtures.dart';

void main() {
  late Directory tempRoot;
  late Directory homeDir;
  late GeneratorRunner runner;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('devkit_screen_');
    homeDir = await Directory.systemTemp.createTemp('devkit_screen_home_');
    final configService = ConfigService(homeOverride: homeDir.path);
    await writeFlutterPubspec(tempRoot.path, chicoUi: true, chicoKit: true);
    await configService.initProjectConfig(
      projectRoot: tempRoot.path,
      config: chicoEnabledConfig(projectName: 'shop_app'),
    );
    runner = GeneratorRunner(
      registry: GeneratorRegistry(generators: [ScreenGenerator()]),
      configService: configService,
    );
  });

  tearDown(() async {
    await tempRoot.delete(recursive: true);
    await homeDir.delete(recursive: true);
  });

  test('generates chico screen page', () async {
    final result = await runner.run(
      projectRoot: tempRoot.path,
      generatorName: 'screen',
      targetName: 'ProductDetails',
      extra: {'tests': false},
    );

    expect(result.writes.createdCount, 1);
    final source = File(
      p.join(
        tempRoot.path,
        'lib',
        'presentation',
        'pages',
        'product_details_page.dart',
      ),
    ).readAsStringSync();
    expect(source, contains('class ProductDetailsPage'));
    expect(source, contains('ChicoScaffold'));
  });

  test('chico screen test imports ChicoApp package', () async {
    final result = await runner.run(
      projectRoot: tempRoot.path,
      generatorName: 'screen',
      targetName: 'Checkout',
      extra: {'tests': true},
    );

    expect(result.writes.createdCount, 2);
    final testSource = File(
      p.join(
        tempRoot.path,
        'test',
        'presentation',
        'pages',
        'checkout_page_test.dart',
      ),
    ).readAsStringSync();
    expect(testSource, contains("import 'package:chico_kit/chico_kit.dart';"));
    expect(testSource, contains('ChicoApp(home: CheckoutPage())'));
    expect(testSource, isNot(contains("import 'package:test/test.dart';")));
  });
}
