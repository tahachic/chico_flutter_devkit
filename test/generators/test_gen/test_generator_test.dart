import 'dart:io';

import 'package:chico_flutter_devkit/chico_flutter_devkit.dart';
import 'package:chico_flutter_devkit/src/generators/test_gen/test_generator.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test('generates unit and widget test scaffolds', () async {
    final tempRoot = await Directory.systemTemp.createTemp('devkit_tg_');
    final homeDir = await Directory.systemTemp.createTemp('devkit_tg_home_');
    addTearDown(() async {
      await tempRoot.delete(recursive: true);
      await homeDir.delete(recursive: true);
    });

    final configService = ConfigService(homeOverride: homeDir.path);
    await configService.initProjectConfig(
      projectRoot: tempRoot.path,
      config: DevKitConfigDefaults.create(projectName: 'shop_app'),
    );

    final runner = GeneratorRunner(
      registry: GeneratorRegistry(generators: [TestGenerator()]),
      configService: configService,
    );

    await runner.run(
      projectRoot: tempRoot.path,
      generatorName: 'test',
      targetName: 'Product',
      extra: {'kind': 'unit', 'target': 'model'},
    );
    final unitTest = File(
      p.join(tempRoot.path, 'test', 'model', 'product_test.dart'),
    ).readAsStringSync();
    expect(
      unitTest,
      contains("import 'package:flutter_test/flutter_test.dart';"),
    );

    await runner.run(
      projectRoot: tempRoot.path,
      generatorName: 'test',
      targetName: 'ProductCard',
      extra: {'kind': 'widget', 'target': 'widgets'},
    );
    final widgetTest = File(
      p.join(tempRoot.path, 'test', 'widgets', 'product_card_test.dart'),
    ).readAsStringSync();
    expect(widgetTest, contains('testWidgets'));
  });
}
