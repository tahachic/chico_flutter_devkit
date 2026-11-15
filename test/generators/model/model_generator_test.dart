import 'dart:io';

import 'package:chico_flutter_devkit/chico_flutter_devkit.dart';
import 'package:chico_flutter_devkit/src/generators/model/model_generator.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tempRoot;
  late Directory homeDir;
  late ConfigService configService;
  late GeneratorRunner runner;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('devkit_model_');
    homeDir = await Directory.systemTemp.createTemp('devkit_model_home_');
    configService = ConfigService(homeOverride: homeDir.path);
    await configService.initProjectConfig(
      projectRoot: tempRoot.path,
      config: DevKitConfigDefaults.create(projectName: 'shop_app'),
    );
    runner = GeneratorRunner(
      registry: GeneratorRegistry(generators: [ModelGenerator()]),
      configService: configService,
    );
  });

  tearDown(() async {
    await tempRoot.delete(recursive: true);
    await homeDir.delete(recursive: true);
  });

  test('generates model from fields', () async {
    final result = await runner.run(
      projectRoot: tempRoot.path,
      generatorName: 'model',
      targetName: 'Product',
      extra: {
        'fields': 'id:String,name:String,price:double?,tags:List<String>',
        'tests': true,
      },
    );

    expect(result.writes.createdCount, 2);
    final file = File(p.join(tempRoot.path, 'lib', 'models', 'product.dart'));
    final source = file.readAsStringSync();
    expect(source, contains('class Product'));
    expect(source, contains('factory Product.fromJson'));
    expect(source, contains('Map<String, dynamic> toJson()'));
    expect(source, contains('Product copyWith'));
    final testSource = File(
      p.join(tempRoot.path, 'test', 'models', 'product_test.dart'),
    ).readAsStringSync();
    expect(
      testSource,
      contains("import 'package:flutter_test/flutter_test.dart';"),
    );
    expect(testSource, isNot(contains("import 'package:test/test.dart';")));
  });

  test('generates model from JSON', () async {
    final result = await runner.run(
      projectRoot: tempRoot.path,
      generatorName: 'model',
      targetName: 'Order',
      extra: {
        'fromJson': '''
{
  "id": "1",
  "total": 12.5,
  "created_at": "2024-01-01T00:00:00Z",
  "active": true
}
''',
        'tests': false,
      },
    );

    expect(result.writes.createdCount, 1);
    final source = File(
      p.join(tempRoot.path, 'lib', 'models', 'order.dart'),
    ).readAsStringSync();
    expect(source, contains('final String id;'));
    expect(source, contains('final double total;'));
    expect(source, contains('final DateTime createdAt;'));
    expect(source, contains('final bool active;'));
  });

  test('dry-run does not write files', () async {
    final result = await runner.run(
      projectRoot: tempRoot.path,
      generatorName: 'model',
      targetName: 'Cart',
      dryRun: true,
      extra: {'fields': 'id:String', 'tests': false},
    );
    expect(result.isDryRun, isTrue);
    expect(
      File(p.join(tempRoot.path, 'lib', 'models', 'cart.dart')).existsSync(),
      isFalse,
    );
  });
}
