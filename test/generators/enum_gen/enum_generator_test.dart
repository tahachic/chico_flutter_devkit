import 'dart:io';

import 'package:chico_flutter_devkit/chico_flutter_devkit.dart';
import 'package:chico_flutter_devkit/src/generators/enum_gen/enum_generator.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test('generates enum with values', () async {
    final tempRoot = await Directory.systemTemp.createTemp('devkit_enum_');
    final homeDir = await Directory.systemTemp.createTemp('devkit_enum_home_');
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
      registry: GeneratorRegistry(generators: [EnumGenerator()]),
      configService: configService,
    );

    final result = await runner.run(
      projectRoot: tempRoot.path,
      generatorName: 'enum',
      targetName: 'OrderStatus',
      extra: {'values': 'pending,shipped,delivered', 'tests': false},
    );

    expect(result.writes.createdCount, 1);
    final source = File(
      p.join(tempRoot.path, 'lib', 'enums', 'order_status.dart'),
    ).readAsStringSync();
    expect(source, contains('enum OrderStatus'));
    expect(source, contains('pending,'));
    expect(source, contains('shipped,'));
  });

  test('rejects missing values', () async {
    final tempRoot = await Directory.systemTemp.createTemp('devkit_enum2_');
    final homeDir = await Directory.systemTemp.createTemp('devkit_enum2_home_');
    addTearDown(() async {
      await tempRoot.delete(recursive: true);
      await homeDir.delete(recursive: true);
    });

    final configService = ConfigService(homeOverride: homeDir.path);
    final runner = GeneratorRunner(
      registry: GeneratorRegistry(generators: [EnumGenerator()]),
      configService: configService,
    );

    expect(
      () => runner.run(
        projectRoot: tempRoot.path,
        generatorName: 'enum',
        targetName: 'OrderStatus',
      ),
      throwsA(isA<InvalidUsageException>()),
    );
  });
}
