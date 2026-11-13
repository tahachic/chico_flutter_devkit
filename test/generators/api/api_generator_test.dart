import 'dart:io';

import 'package:chico_flutter_devkit/chico_flutter_devkit.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tempRoot;
  late Directory homeDir;
  late ConfigService configService;
  late GeneratorRunner runner;
  late String fixtureSpec;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('devkit_api_');
    homeDir = await Directory.systemTemp.createTemp('devkit_api_home_');
    configService = ConfigService(homeOverride: homeDir.path);
    await configService.initProjectConfig(
      projectRoot: tempRoot.path,
      config: DevKitConfigDefaults.create(projectName: 'shop_app'),
    );
    runner = GeneratorRunner(
      registry: createDefaultGeneratorRegistry(),
      configService: configService,
    );
    fixtureSpec = p.absolute(
      p.join('test', 'fixtures', 'openapi', 'shop_api.yaml'),
    );
  });

  tearDown(() async {
    await tempRoot.delete(recursive: true);
    await homeDir.delete(recursive: true);
  });

  test('generates isolated client, models, auth, and exception', () async {
    final result = await runner.run(
      projectRoot: tempRoot.path,
      generatorName: 'api',
      targetName: 'shop',
      force: true,
      extra: {'spec': fixtureSpec},
    );

    expect(result.writes.createdCount, greaterThan(3));

    final client = File(
      p.join(tempRoot.path, 'lib', 'api', 'shop', 'generated', 'client.dart'),
    );
    final auth = File(
      p.join(tempRoot.path, 'lib', 'api', 'shop', 'generated', 'auth.dart'),
    );
    final product = File(
      p.join(
        tempRoot.path,
        'lib',
        'api',
        'shop',
        'generated',
        'models',
        'product.dart',
      ),
    );
    final readme = File(
      p.join(tempRoot.path, 'lib', 'api', 'shop', 'README.md'),
    );

    expect(client.existsSync(), isTrue);
    expect(auth.existsSync(), isTrue);
    expect(product.existsSync(), isTrue);
    expect(readme.existsSync(), isTrue);

    final clientSource = client.readAsStringSync();
    expect(clientSource, contains('GENERATED CODE - DO NOT MODIFY BY HAND'));
    expect(clientSource, contains('final class ShopApi'));
    expect(clientSource, contains('listProducts'));
    expect(clientSource, contains('getProduct'));
    expect(clientSource, contains('createProduct'));
    expect(clientSource, contains('https://api.shop.example.com/v1'));

    expect(auth.readAsStringSync(), contains('bearerToken'));
    final productSource = product.readAsStringSync();
    expect(productSource, contains('class Product'));
    expect(
      productSource,
      contains("import 'product_status.dart';"),
      reason: 'Cross-schema model references must be imported',
    );
  });

  test('requires --spec', () async {
    expect(
      () => runner.run(
        projectRoot: tempRoot.path,
        generatorName: 'api',
        targetName: 'shop',
      ),
      throwsA(isA<InvalidUsageException>()),
    );
  });

  test('honors base-url override', () async {
    await runner.run(
      projectRoot: tempRoot.path,
      generatorName: 'api',
      targetName: 'shop',
      force: true,
      extra: {'spec': fixtureSpec, 'baseUrl': 'https://override.example.com'},
    );
    final clientSource = File(
      p.join(tempRoot.path, 'lib', 'api', 'shop', 'generated', 'client.dart'),
    ).readAsStringSync();
    expect(clientSource, contains('https://override.example.com'));
  });
}
