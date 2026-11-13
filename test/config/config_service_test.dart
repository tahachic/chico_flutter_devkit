import 'dart:io';

import 'package:chico_flutter_devkit/chico_flutter_devkit.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tempRoot;
  late Directory homeDir;
  late ConfigService service;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('devkit_cfg_');
    homeDir = await Directory.systemTemp.createTemp('devkit_home_');
    service = ConfigService(homeOverride: homeDir.path);
  });

  tearDown(() async {
    if (tempRoot.existsSync()) {
      await tempRoot.delete(recursive: true);
    }
    if (homeDir.existsSync()) {
      await homeDir.delete(recursive: true);
    }
  });

  test('resolve returns defaults when no files exist', () {
    final resolved = service.resolve(
      projectRoot: tempRoot.path,
      projectNameHint: 'demo_app',
    );

    expect(resolved.projectConfigExists, isFalse);
    expect(resolved.userConfigExists, isFalse);
    expect(resolved.config.project.name, 'demo_app');
    expect(resolved.config.schemaVersion, currentSchemaVersion);
  });

  test('resolve lowercases uppercase temp directory names', () {
    // Simulates Linux/macOS Directory.createTemp suffixes.
    final resolved = service.resolve(
      projectRoot: p.join(tempRoot.path, 'devkit_gen_XDPSQA'),
    );
    expect(resolved.config.project.name, 'devkit_gen_xdpsqa');
  });

  test('packageNameFromDirectory sanitizes invalid basenames', () {
    expect(
      ConfigService.packageNameFromDirectory('/tmp/devkit_gen_XDPSQA'),
      'devkit_gen_xdpsqa',
    );
    expect(ConfigService.packageNameFromDirectory('/tmp/123bad'), 'app_123bad');
  });

  test('initProjectConfig writes .chico/devkit.yaml', () async {
    final path = await service.initProjectConfig(
      projectRoot: tempRoot.path,
      config: DevKitConfigDefaults.create(projectName: 'shop_app'),
    );

    expect(File(path).existsSync(), isTrue);
    expect(p.basename(path), 'devkit.yaml');
    expect(p.basename(p.dirname(path)), '.chico');

    final resolved = service.resolve(projectRoot: tempRoot.path);
    expect(resolved.projectConfigExists, isTrue);
    expect(resolved.config.project.name, 'shop_app');
  });

  test('initProjectConfig refuses overwrite without force', () async {
    await service.initProjectConfig(
      projectRoot: tempRoot.path,
      config: DevKitConfigDefaults.create(projectName: 'shop_app'),
    );

    expect(
      () => service.initProjectConfig(
        projectRoot: tempRoot.path,
        config: DevKitConfigDefaults.create(projectName: 'other'),
      ),
      throwsA(isA<ConfigException>()),
    );
  });

  test(
    'user config applies when project omits the key; project wins otherwise',
    () async {
      final userFile = File(
        ConfigPaths.userConfigFile(homeOverride: homeDir.path),
      );
      await userFile.parent.create(recursive: true);
      await userFile.writeAsString('''
schemaVersion: 1
project:
  organization: com.user
flutter:
  state_management: riverpod
''');

      final projectFile = File(ConfigPaths.projectConfigFile(tempRoot.path));
      await projectFile.parent.create(recursive: true);
      await projectFile.writeAsString('''
schemaVersion: 1
project:
  name: shop_app
  organization: com.project
''');

      final resolved = service.resolve(projectRoot: tempRoot.path);
      expect(resolved.userConfigExists, isTrue);
      expect(resolved.projectConfigExists, isTrue);
      expect(resolved.config.project.organization, 'com.project');
      expect(resolved.config.flutter.stateManagement, StateManagement.riverpod);
    },
  );

  test('CLI overrides win without writing files', () {
    final resolved = service.resolve(
      projectRoot: tempRoot.path,
      projectNameHint: 'shop_app',
      overrides: const ConfigOverrides(
        stateManagement: StateManagement.provider,
        overwrite: true,
      ),
    );

    expect(resolved.config.flutter.stateManagement, StateManagement.provider);
    expect(resolved.config.generation.overwrite, isTrue);
    expect(resolved.projectConfigExists, isFalse);
  });

  test('setProjectValue updates dotted keys', () async {
    await service.initProjectConfig(
      projectRoot: tempRoot.path,
      config: DevKitConfigDefaults.create(projectName: 'shop_app'),
    );

    final updated = await service.setProjectValue(
      projectRoot: tempRoot.path,
      key: 'project.architecture',
      value: 'layered',
    );

    expect(updated.project.architecture, Architecture.layered);

    final resolved = service.resolve(projectRoot: tempRoot.path);
    expect(resolved.config.project.architecture, Architecture.layered);
  });

  test('invalid YAML raises ConfigException', () async {
    final file = File(ConfigPaths.projectConfigFile(tempRoot.path));
    await file.parent.create(recursive: true);
    await file.writeAsString('project: [unterminated');

    expect(
      () => service.resolve(projectRoot: tempRoot.path),
      throwsA(isA<ConfigException>()),
    );
  });
}
