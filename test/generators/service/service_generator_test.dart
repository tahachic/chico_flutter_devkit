import 'dart:io';

import 'package:chico_flutter_devkit/chico_flutter_devkit.dart';
import 'package:chico_flutter_devkit/src/generators/service/service_generator.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test('generates service interface and impl', () async {
    final tempRoot = await Directory.systemTemp.createTemp('devkit_svc_');
    final homeDir = await Directory.systemTemp.createTemp('devkit_svc_home_');
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
      registry: GeneratorRegistry(generators: [ServiceGenerator()]),
      configService: configService,
    );

    final result = await runner.run(
      projectRoot: tempRoot.path,
      generatorName: 'service',
      targetName: 'NotificationService',
      extra: {'tests': true},
    );

    expect(result.writes.createdCount, 3);
    expect(
      File(
        p.join(tempRoot.path, 'lib', 'services', 'notification_service.dart'),
      ).existsSync(),
      isTrue,
    );
    expect(
      File(
        p.join(
          tempRoot.path,
          'lib',
          'services',
          'notification_service_impl.dart',
        ),
      ).existsSync(),
      isTrue,
    );
  });
}
