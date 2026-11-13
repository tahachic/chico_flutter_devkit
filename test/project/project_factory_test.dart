import 'dart:io';

import 'package:chico_flutter_devkit/chico_flutter_devkit.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tempRoot;
  late Directory homeDir;
  late FakeFlutterCli flutterCli;
  late ConfigService configService;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('devkit_create_');
    homeDir = await Directory.systemTemp.createTemp('devkit_create_home_');
    flutterCli = FakeFlutterCli();
    configService = ConfigService(homeOverride: homeDir.path);
  });

  tearDown(() async {
    await tempRoot.delete(recursive: true);
    await homeDir.delete(recursive: true);
  });

  test('creates project overlay with chico and example feature', () async {
    final factory = ProjectFactory(
      configService: configService,
      flutterCli: flutterCli,
      runPubGet: true,
    );

    final projectPath = p.join(tempRoot.path, 'shop_app');
    final result = await factory.create(
      ProjectCreateOptions(
        name: 'shop_app',
        organization: 'com.example',
        architecture: Architecture.clean,
        stateManagement: StateManagement.bloc,
        routing: Routing.goRouter,
        dependencyInjection: DependencyInjection.getIt,
        enableChicoUi: true,
        enableChicoKit: true,
        enableChicoServices: true,
        enableLocalization: true,
        enableDarkMode: true,
        enableLogging: true,
        enableErrorHandling: true,
        generateExampleFeature: true,
        outputDirectory: projectPath,
      ),
    );

    expect(result.projectPath, projectPath);
    expect(flutterCli.created, contains(projectPath));
    expect(flutterCli.pubGetCalls, contains(projectPath));
    expect(File(p.join(projectPath, 'lib', 'main.dart')).existsSync(), isTrue);
    expect(File(p.join(projectPath, 'lib', 'app.dart')).existsSync(), isTrue);
    final appSource = File(
      p.join(projectPath, 'lib', 'app.dart'),
    ).readAsStringSync();
    expect(
      appSource,
      isNot(contains("package:flutter/material.dart")),
      reason: 'Chico apps must not import deprecated flutter/material.dart',
    );
    expect(appSource, contains("package:flutter/widgets.dart"));
    expect(appSource, contains('ChicoApp'));
    expect(
      File(p.join(projectPath, '.chico', 'devkit.yaml')).existsSync(),
      isTrue,
    );
    expect(
      File(
        p.join(
          projectPath,
          'lib',
          'features',
          'home',
          'presentation',
          'pages',
          'home_page.dart',
        ),
      ).existsSync(),
      isTrue,
    );
    expect(
      File(
        p.join(
          projectPath,
          'lib',
          'features',
          'example',
          'domain',
          'entities',
          'example.dart',
        ),
      ).existsSync(),
      isTrue,
    );

    final pubspec = await File(
      p.join(projectPath, 'pubspec.yaml'),
    ).readAsString();
    expect(pubspec, contains('chico_ui'));
    expect(pubspec, contains('go_router'));
    expect(pubspec, contains('flutter_bloc'));
    expect(pubspec, contains('get_it'));

    final main = await File(
      p.join(projectPath, 'lib', 'main.dart'),
    ).readAsString();
    expect(main, contains('ChicoServices.init'));
  });

  test('CLI create uses injected flutter cli', () async {
    final app = CliApp(
      configService: configService,
      flutterCli: flutterCli,
      projectRoot: tempRoot.path,
    );

    final code = await app.run([
      'create',
      'demo_app',
      '--no-interactive',
      '--no-example-feature',
      '--no-pub-get',
      '--output',
      p.join(tempRoot.path, 'demo_app'),
    ]);
    expect(code, ExitCodes.success);
    expect(
      File(p.join(tempRoot.path, 'demo_app', 'lib', 'app.dart')).existsSync(),
      isTrue,
    );
  });
}
