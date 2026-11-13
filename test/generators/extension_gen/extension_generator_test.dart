import 'dart:io';

import 'package:chico_flutter_devkit/chico_flutter_devkit.dart';
import 'package:chico_flutter_devkit/src/generators/extension_gen/extension_generator.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test('generates string extension', () async {
    final tempRoot = await Directory.systemTemp.createTemp('devkit_ext_');
    final homeDir = await Directory.systemTemp.createTemp('devkit_ext_home_');
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
      registry: GeneratorRegistry(generators: [ExtensionGenerator()]),
      configService: configService,
    );

    final result = await runner.run(
      projectRoot: tempRoot.path,
      generatorName: 'extension',
      targetName: 'StringX',
      extra: {'on': 'String', 'tests': true},
    );

    expect(result.writes.createdCount, 2);
    final source = File(
      p.join(tempRoot.path, 'lib', 'extensions', 'string_x.dart'),
    ).readAsStringSync();
    expect(source, contains('extension StringX on String'));
    expect(source, contains('isBlank'));
  });
}
