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
      isNot(contains('package:flutter/material.dart')),
      reason: 'Chico apps must not import deprecated flutter/material.dart',
    );
    expect(appSource, contains('package:flutter/widgets.dart'));
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
    expect(
      File(
        p.join(projectPath, 'lib', 'core', 'di', 'core_module.dart'),
      ).existsSync(),
      isTrue,
    );
    final injector = await File(
      p.join(projectPath, 'lib', 'core', 'di', 'injector.dart'),
    ).readAsString();
    expect(injector, contains('registerCore'));
    expect(injector, contains('registerFeatures'));
    expect(File(p.join(projectPath, 'l10n.yaml')).existsSync(), isTrue);
    expect(
      File(p.join(projectPath, 'lib', 'l10n', 'app_en.arb')).existsSync(),
      isTrue,
    );
    expect(pubspec, contains('flutter_localizations'));
    expect(pubspec, contains('generate: true'));
    final app = await File(
      p.join(projectPath, 'lib', 'app.dart'),
    ).readAsString();
    expect(app, contains('AppLocalizations.localizationsDelegates'));
  });

  test('creates Riverpod DI composition root', () async {
    final factory = ProjectFactory(
      configService: configService,
      flutterCli: flutterCli,
      runPubGet: false,
    );

    final projectPath = p.join(tempRoot.path, 'river_app');
    await factory.create(
      ProjectCreateOptions(
        name: 'river_app',
        organization: 'com.example',
        architecture: Architecture.clean,
        stateManagement: StateManagement.riverpod,
        routing: Routing.goRouter,
        dependencyInjection: DependencyInjection.riverpod,
        enableChicoUi: false,
        enableChicoKit: false,
        enableChicoServices: false,
        enableLocalization: true,
        enableDarkMode: true,
        enableLogging: true,
        enableErrorHandling: true,
        generateExampleFeature: false,
        outputDirectory: projectPath,
      ),
    );

    final injector = File(
      p.join(projectPath, 'lib', 'core', 'di', 'injector.dart'),
    ).readAsStringSync();
    expect(injector, contains('ProviderContainer'));
    expect(injector, contains('appContainer'));
    expect(
      File(
        p.join(projectPath, 'lib', 'core', 'di', 'app_providers.dart'),
      ).existsSync(),
      isTrue,
    );
    final app = File(p.join(projectPath, 'lib', 'app.dart')).readAsStringSync();
    expect(app, contains('UncontrolledProviderScope'));
    expect(app, contains('appContainer'));
    final pubspec = File(
      p.join(projectPath, 'pubspec.yaml'),
    ).readAsStringSync();
    expect(pubspec, contains('flutter_riverpod'));
  });

  test('creates Navigator 1.0 routing without go_router', () async {
    final factory = ProjectFactory(
      configService: configService,
      flutterCli: flutterCli,
      runPubGet: false,
    );

    final projectPath = p.join(tempRoot.path, 'nav_app');
    await factory.create(
      ProjectCreateOptions(
        name: 'nav_app',
        organization: 'com.example',
        architecture: Architecture.clean,
        stateManagement: StateManagement.bloc,
        routing: Routing.navigator,
        dependencyInjection: DependencyInjection.getIt,
        enableChicoUi: false,
        enableChicoKit: false,
        enableChicoServices: false,
        enableLocalization: false,
        enableDarkMode: true,
        enableLogging: true,
        enableErrorHandling: true,
        generateExampleFeature: false,
        outputDirectory: projectPath,
      ),
    );

    final app = File(p.join(projectPath, 'lib', 'app.dart')).readAsStringSync();
    expect(app, contains('initialRoute: AppRouter.home'));
    expect(app, contains('routes: AppRouter.routes'));
    expect(app, isNot(contains('MaterialApp.router')));
    final router = File(
      p.join(projectPath, 'lib', 'core', 'routing', 'app_router.dart'),
    ).readAsStringSync();
    expect(router, contains('Map<String, WidgetBuilder>'));
    expect(router, contains('featureRoutes'));
    final routes = File(
      p.join(projectPath, 'lib', 'core', 'routing', 'feature_routes.dart'),
    ).readAsStringSync();
    expect(routes, contains('Map<String, WidgetBuilder>'));
    final pubspec = File(
      p.join(projectPath, 'pubspec.yaml'),
    ).readAsStringSync();
    expect(pubspec, isNot(contains('go_router')));
  });

  test('creates manual DI composition root with factories', () async {
    final factory = ProjectFactory(
      configService: configService,
      flutterCli: flutterCli,
      runPubGet: false,
    );

    final projectPath = p.join(tempRoot.path, 'manual_app');
    await factory.create(
      ProjectCreateOptions(
        name: 'manual_app',
        organization: 'com.example',
        architecture: Architecture.clean,
        stateManagement: StateManagement.bloc,
        routing: Routing.goRouter,
        dependencyInjection: DependencyInjection.manual,
        enableChicoUi: false,
        enableChicoKit: false,
        enableChicoServices: false,
        enableLocalization: true,
        enableDarkMode: true,
        enableLogging: true,
        enableErrorHandling: true,
        generateExampleFeature: false,
        outputDirectory: projectPath,
      ),
    );

    final injector = File(
      p.join(projectPath, 'lib', 'core', 'di', 'injector.dart'),
    ).readAsStringSync();
    expect(injector, contains('AppServices'));
    expect(injector, contains('ServiceLocator'));
    expect(
      File(
        p.join(projectPath, 'lib', 'core', 'di', 'feature_factories.dart'),
      ).existsSync(),
      isTrue,
    );
    expect(
      File(
        p.join(projectPath, 'lib', 'core', 'di', 'feature_registrations.dart'),
      ).existsSync(),
      isFalse,
    );
  });

  test('CLI create is Material-first without --chico', () async {
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
    final appSource = File(
      p.join(tempRoot.path, 'demo_app', 'lib', 'app.dart'),
    ).readAsStringSync();
    expect(appSource, contains('MaterialApp'));
    expect(appSource, contains('AppTheme.light'));
    expect(appSource, isNot(contains('ChicoApp')));
    final pubspec = File(
      p.join(tempRoot.path, 'demo_app', 'pubspec.yaml'),
    ).readAsStringSync();
    expect(pubspec, isNot(contains('chico_ui')));
  });

  test('Material-first create uses material_ui when Flutter ≥ 3.47', () async {
    final materialCli = FakeFlutterCli(materialUiSupported: true);
    final factory = ProjectFactory(
      configService: configService,
      flutterCli: materialCli,
      runPubGet: true,
    );

    final projectPath = p.join(tempRoot.path, 'material_ui_app');
    await factory.create(
      ProjectCreateOptions(
        name: 'material_ui_app',
        organization: 'com.example',
        architecture: Architecture.clean,
        stateManagement: StateManagement.bloc,
        routing: Routing.goRouter,
        dependencyInjection: DependencyInjection.getIt,
        enableChicoUi: false,
        enableChicoKit: false,
        enableChicoServices: false,
        enableLocalization: true,
        enableDarkMode: true,
        enableLogging: true,
        enableErrorHandling: true,
        generateExampleFeature: false,
        outputDirectory: projectPath,
      ),
    );

    final app = File(p.join(projectPath, 'lib', 'app.dart')).readAsStringSync();
    expect(app, contains('package:material_ui/material_ui.dart'));
    expect(app, isNot(contains('package:flutter/material.dart')));
    final pubspec = File(
      p.join(projectPath, 'pubspec.yaml'),
    ).readAsStringSync();
    expect(pubspec, contains('material_ui:'));
    expect(pubspec, contains('cupertino_ui:'));
    expect(materialCli.migrateDesignWidgetsCalls, contains(projectPath));
  });

  test('CLI create --chico enables Chico stack', () async {
    final app = CliApp(
      configService: configService,
      flutterCli: flutterCli,
      projectRoot: tempRoot.path,
    );

    final code = await app.run([
      'create',
      'chico_demo',
      '--chico',
      '--no-interactive',
      '--no-example-feature',
      '--no-pub-get',
      '--output',
      p.join(tempRoot.path, 'chico_demo'),
    ]);
    expect(code, ExitCodes.success);
    final appSource = File(
      p.join(tempRoot.path, 'chico_demo', 'lib', 'app.dart'),
    ).readAsStringSync();
    expect(appSource, contains('ChicoApp'));
    final pubspec = File(
      p.join(tempRoot.path, 'chico_demo', 'pubspec.yaml'),
    ).readAsStringSync();
    expect(pubspec, contains('chico_ui'));
    expect(pubspec, contains('chico_kit'));
    expect(pubspec, contains('chico_services'));
  });
}
