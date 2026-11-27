import 'dart:io';

import 'package:chico_flutter_devkit/chico_flutter_devkit.dart';
import 'package:chico_flutter_devkit/src/generators/auth/auth_generator.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../../support/project_fixtures.dart';

void main() {
  late Directory tempRoot;
  late Directory homeDir;
  late ConfigService configService;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('devkit_auth_');
    homeDir = await Directory.systemTemp.createTemp('devkit_auth_home_');
    configService = ConfigService(homeOverride: homeDir.path);
    await writeFlutterPubspec(tempRoot.path, name: 'shop_app');
    await configService.initProjectConfig(
      projectRoot: tempRoot.path,
      config: DevKitConfigDefaults.create(projectName: 'shop_app'),
      force: true,
    );
  });

  tearDown(() async {
    await tempRoot.delete(recursive: true);
    await homeDir.delete(recursive: true);
  });

  test('generates session auth + app_config + get_it registrations', () async {
    final runner = GeneratorRunner(
      registry: GeneratorRegistry(generators: [AuthGenerator()]),
      configService: configService,
    );

    final result = await runner.run(
      projectRoot: tempRoot.path,
      generatorName: 'auth',
      targetName: 'session',
    );

    expect(result.writes.createdCount, greaterThanOrEqualTo(3));
    final sessionAuth = File(
      p.join(tempRoot.path, 'lib', 'core', 'auth', 'session_auth.dart'),
    ).readAsStringSync();
    expect(sessionAuth, contains('signInStub'));
    expect(sessionAuth, contains('Future<void> signOut()'));
    expect(
      File(
        p.join(tempRoot.path, 'lib', 'core', 'config', 'app_config.dart'),
      ).readAsStringSync(),
      contains('String.fromEnvironment'),
    );
    expect(
      File(
        p.join(tempRoot.path, 'lib', 'core', 'di', 'auth_registrations.dart'),
      ).existsSync(),
      isTrue,
    );
  });

  test('unknown auth pack fails closed', () async {
    final runner = GeneratorRunner(
      registry: GeneratorRegistry(generators: [AuthGenerator()]),
      configService: configService,
    );
    await expectLater(
      () => runner.run(
        projectRoot: tempRoot.path,
        generatorName: 'auth',
        targetName: 'oauth',
      ),
      throwsA(isA<InvalidUsageException>()),
    );
  });
}
