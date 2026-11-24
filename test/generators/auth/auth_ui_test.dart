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
    expect(login.readAsStringSync(), contains('signInStub'));

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
}
