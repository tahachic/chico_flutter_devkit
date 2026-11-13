import 'dart:io';

import 'package:chico_flutter_devkit/chico_flutter_devkit.dart';
import 'package:chico_flutter_devkit/src/integrations/chico/chico_integration_service.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tempRoot;
  late Directory homeDir;
  late ConfigService configService;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('devkit_chico_');
    homeDir = await Directory.systemTemp.createTemp('devkit_chico_home_');
    configService = ConfigService(homeOverride: homeDir.path);
    await File(p.join(tempRoot.path, 'pubspec.yaml')).writeAsString('''
name: shop_app
environment:
  sdk: ^3.8.0
dependencies:
  flutter:
    sdk: flutter
''');
    await Directory(p.join(tempRoot.path, 'lib')).create();
  });

  tearDown(() async {
    await tempRoot.delete(recursive: true);
    await homeDir.delete(recursive: true);
  });

  test('add chico_ui updates pubspec', () async {
    final service = ChicoIntegrationService(configService: configService);
    final result = await service.addPackage(
      projectRoot: tempRoot.path,
      package: ChicoPackageId.ui,
      writeBootstrap: true,
      force: true,
    );

    expect(result.addedPackages, contains('chico_ui'));
    expect(
      File(
        p.join(tempRoot.path, 'lib', 'core', 'chico_bootstrap.dart'),
      ).existsSync(),
      isTrue,
    );
  });

  test('setup chico adds full stack', () async {
    final service = ChicoIntegrationService(configService: configService);
    final result = await service.setup(
      projectRoot: tempRoot.path,
      packages: ChicoPackageId.values,
      writeBootstrap: true,
      force: true,
    );

    final pubspec = await File(
      p.join(tempRoot.path, 'pubspec.yaml'),
    ).readAsString();
    expect(pubspec, contains('chico_ui'));
    expect(pubspec, contains('chico_kit'));
    expect(pubspec, contains('chico_services'));
    expect(result.docs, isNotEmpty);
  });
}
