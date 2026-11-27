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
    tempRoot = await Directory.systemTemp.createTemp('devkit_auth_ui_');
    homeDir = await Directory.systemTemp.createTemp('devkit_auth_ui_home_');
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

  Future<void> seedRouterAndInjector() async {
    final router = File(
      p.join(tempRoot.path, 'lib', 'core', 'routing', 'app_router.dart'),
    );
    await router.parent.create(recursive: true);
    await router.writeAsString('''
import 'package:go_router/go_router.dart';
import 'package:shop_app/features/home/presentation/pages/home_page.dart';
import 'feature_routes.dart';

abstract final class AppRouter {
  static final GoRouter router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (context, state) => const HomePage()),
      ...featureRoutes,
    ],
  );
}
''');
    final injector = File(
      p.join(tempRoot.path, 'lib', 'core', 'di', 'injector.dart'),
    );
    await injector.parent.create(recursive: true);
    await injector.writeAsString('''
import 'package:get_it/get_it.dart';
import 'feature_registrations.dart';

final getIt = GetIt.instance;

Future<void> configureDependencies() async {
  registerFeatures(getIt);
}
''');
  }

  test('auth session --ui writes login page and route guard', () async {
    await seedRouterAndInjector();
    final runner = GeneratorRunner(
      registry: GeneratorRegistry(generators: [AuthGenerator()]),
      configService: configService,
    );

    final result = await runner.run(
      projectRoot: tempRoot.path,
      generatorName: 'auth',
      targetName: 'session',
      extra: {'ui': true},
    );

    expect(result.message, contains('login'));
    final login = File(
      p.join(
        tempRoot.path,
        'lib',
        'features',
        'auth',
        'presentation',
        'pages',
        'login_page.dart',
      ),
    );
    expect(login.existsSync(), isTrue);
    final loginSource = login.readAsStringSync();
    expect(loginSource, contains('signInStub'));
    expect(loginSource, contains('Stub login:'));
    expect(loginSource, contains('Sign out'));
    expect(loginSource, contains('signOut()'));
    expect(loginSource, contains("package:flutter/material.dart"));
    expect(loginSource, isNot(contains("package:material_ui/material.dart")));

    final router = File(
      p.join(tempRoot.path, 'lib', 'core', 'routing', 'app_router.dart'),
    ).readAsStringSync();
    expect(router, contains("path: '/login'"));
    expect(router, contains("path.startsWith('/features')"));
    expect(router, contains("return '/login'"));

    final injector = File(
      p.join(tempRoot.path, 'lib', 'core', 'di', 'injector.dart'),
    ).readAsStringSync();
    expect(injector, contains('registerAuth(getIt);'));
  });

  test('auth --ui uses material_ui import when package is present', () async {
    await writeFlutterPubspec(tempRoot.path, name: 'shop_app');
    final pubspec = File(p.join(tempRoot.path, 'pubspec.yaml'));
    final raw = pubspec.readAsStringSync().replaceFirst(
      'dependencies:\n  flutter:',
      'dependencies:\n  material_ui: ^1.0.0\n  flutter:',
    );
    await pubspec.writeAsString(raw);
    await seedRouterAndInjector();

    final runner = GeneratorRunner(
      registry: GeneratorRegistry(generators: [AuthGenerator()]),
      configService: configService,
    );
    await runner.run(
      projectRoot: tempRoot.path,
      generatorName: 'auth',
      targetName: 'session',
      extra: {'ui': true},
    );

    final login = File(
      p.join(
        tempRoot.path,
        'lib',
        'features',
        'auth',
        'presentation',
        'pages',
        'login_page.dart',
      ),
    ).readAsStringSync();
    expect(login, contains("package:material_ui/material_ui.dart"));
    expect(login, isNot(contains("package:material_ui/material.dart")));
    expect(login, isNot(contains("package:flutter/material.dart")));
  });

  test('auth session without --ui does not write login page', () async {
    final runner = GeneratorRunner(
      registry: GeneratorRegistry(generators: [AuthGenerator()]),
      configService: configService,
    );
    await runner.run(
      projectRoot: tempRoot.path,
      generatorName: 'auth',
      targetName: 'session',
    );
    expect(
      File(
        p.join(
          tempRoot.path,
          'lib',
          'features',
          'auth',
          'presentation',
          'pages',
          'login_page.dart',
        ),
      ).existsSync(),
      isFalse,
    );
  });

  test('auth --ui refuses missing router anchors', () async {
    final runner = GeneratorRunner(
      registry: GeneratorRegistry(generators: [AuthGenerator()]),
      configService: configService,
    );
    await expectLater(
      () => runner.run(
        projectRoot: tempRoot.path,
        generatorName: 'auth',
        targetName: 'session',
        extra: {'ui': true},
      ),
      throwsA(isA<InvalidUsageException>()),
    );
  });

  test('auth --ui refuses broken injector anchors', () async {
    final router = File(
      p.join(tempRoot.path, 'lib', 'core', 'routing', 'app_router.dart'),
    );
    await router.parent.create(recursive: true);
    await router.writeAsString('''
abstract final class AppRouter {
  static final featureRoutes = <dynamic>[];
}
''');
    final injector = File(
      p.join(tempRoot.path, 'lib', 'core', 'di', 'injector.dart'),
    );
    await injector.parent.create(recursive: true);
    await injector.writeAsString('void configure() {}\n');

    final runner = GeneratorRunner(
      registry: GeneratorRegistry(generators: [AuthGenerator()]),
      configService: configService,
    );
    await expectLater(
      () => runner.run(
        projectRoot: tempRoot.path,
        generatorName: 'auth',
        targetName: 'session',
        extra: {'ui': true},
      ),
      throwsA(isA<InvalidUsageException>()),
    );
  });

  test('auth --ui refuses navigator routing', () async {
    await configService.initProjectConfig(
      projectRoot: tempRoot.path,
      config: DevKitConfigDefaults.create(projectName: 'shop_app').copyWith(
        flutter: DevKitConfigDefaults.create(
          projectName: 'shop_app',
        ).flutter.copyWith(routing: Routing.navigator),
      ),
      force: true,
    );
    final runner = GeneratorRunner(
      registry: GeneratorRegistry(generators: [AuthGenerator()]),
      configService: configService,
    );
    await expectLater(
      () => runner.run(
        projectRoot: tempRoot.path,
        generatorName: 'auth',
        targetName: 'session',
        extra: {'ui': true},
      ),
      throwsA(
        isA<InvalidUsageException>().having(
          (e) => e.message,
          'message',
          contains('go_router'),
        ),
      ),
    );
  });

  test('auth --ui refuses non-get_it DI', () async {
    await configService.initProjectConfig(
      projectRoot: tempRoot.path,
      config: DevKitConfigDefaults.create(projectName: 'shop_app').copyWith(
        flutter: DevKitConfigDefaults.create(
          projectName: 'shop_app',
        ).flutter.copyWith(dependencyInjection: DependencyInjection.riverpod),
      ),
      force: true,
    );
    final runner = GeneratorRunner(
      registry: GeneratorRegistry(generators: [AuthGenerator()]),
      configService: configService,
    );
    await expectLater(
      () => runner.run(
        projectRoot: tempRoot.path,
        generatorName: 'auth',
        targetName: 'session',
        extra: {'ui': true},
      ),
      throwsA(
        isA<InvalidUsageException>().having(
          (e) => e.message,
          'message',
          contains('get_it'),
        ),
      ),
    );
  });
}
