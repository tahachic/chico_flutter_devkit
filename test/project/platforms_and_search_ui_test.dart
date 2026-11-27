import 'dart:io';

import 'package:chico_flutter_devkit/chico_flutter_devkit.dart';
import 'package:chico_flutter_devkit/src/generators/feature/feature_generator.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tempRoot;
  late Directory homeDir;
  late ConfigService configService;
  late FakeFlutterCli flutterCli;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('devkit_plat_');
    homeDir = await Directory.systemTemp.createTemp('devkit_plat_home_');
    configService = ConfigService(homeOverride: homeDir.path);
    flutterCli = FakeFlutterCli();
  });

  tearDown(() async {
    await tempRoot.delete(recursive: true);
    await homeDir.delete(recursive: true);
  });

  test('create forwards --platforms to flutter create', () async {
    final factory = ProjectFactory(
      configService: configService,
      flutterCli: flutterCli,
      runPubGet: false,
    );
    await factory.create(
      ProjectCreateOptions(
        name: 'desk_app',
        organization: 'com.example',
        architecture: Architecture.clean,
        stateManagement: StateManagement.bloc,
        routing: Routing.goRouter,
        dependencyInjection: DependencyInjection.getIt,
        enableChicoUi: false,
        enableChicoKit: false,
        enableChicoServices: false,
        enableLocalization: false,
        enableDarkMode: true,
        enableLogging: false,
        enableErrorHandling: false,
        generateExampleFeature: false,
        outputDirectory: p.join(tempRoot.path, 'desk_app'),
        platforms: 'android,ios,web,windows',
      ),
    );
    expect(flutterCli.lastPlatforms, ['android,ios,web,windows']);
  });

  test('feature --search emits TextField search UI', () async {
    final project = p.join(tempRoot.path, 'shop');
    await Directory(project).create();
    await File(p.join(project, 'pubspec.yaml')).writeAsString('''
name: shop
environment:
  sdk: ^3.8.0
dependencies:
  flutter:
    sdk: flutter
flutter:
  uses-material-design: true
''');
    await configService.initProjectConfig(
      projectRoot: project,
      config: DevKitConfigDefaults.create(projectName: 'shop'),
      force: true,
    );
    final regs = File(
      p.join(project, 'lib', 'core', 'di', 'feature_registrations.dart'),
    );
    await regs.parent.create(recursive: true);
    await regs.writeAsString('''
import 'package:get_it/get_it.dart';
// <devkit:feature-di-imports>
// </devkit:feature-di-imports>
void registerFeatures(GetIt getIt) {
// <devkit:feature-registrations>
// </devkit:feature-registrations>
}
''');
    final routes = File(
      p.join(project, 'lib', 'core', 'routing', 'feature_routes.dart'),
    );
    await routes.parent.create(recursive: true);
    await routes.writeAsString('''
import 'package:go_router/go_router.dart';
// <devkit:feature-route-imports>
// </devkit:feature-route-imports>
List<RouteBase> get featureRoutes => [
// <devkit:feature-routes>
// </devkit:feature-routes>
];
''');

    final runner = GeneratorRunner(
      registry: GeneratorRegistry(generators: [FeatureGenerator()]),
      configService: configService,
    );
    await runner.run(
      projectRoot: project,
      generatorName: 'feature',
      targetName: 'products',
      extra: {'search': true, 'pagination': true, 'tests': false},
    );
    final page = File(
      p.join(
        project,
        'lib',
        'features',
        'products',
        'presentation',
        'pages',
        'products_page.dart',
      ),
    ).readAsStringSync();
    expect(page, contains("hintText: 'Search…'"));
    expect(page, contains("child: const Text('Previous')"));
    expect(page, contains("child: const Text('Next')"));
    expect(page, isNot(contains('Search UI hook enabled')));
    expect(page, isNot(contains('Wire to repository.search')));
    expect(page, isNot(contains('Wire to fetchPage')));
    expect(page, contains('ProductsSearched'));
    expect(page, contains('ProductsPageRequested'));

    final bloc = File(
      p.join(
        project,
        'lib',
        'features',
        'products',
        'presentation',
        'bloc',
        'products_bloc.dart',
      ),
    ).readAsStringSync();
    expect(bloc, contains('SearchProducts'));
    expect(bloc, contains('GetProductsPage'));
    expect(bloc, contains('_onSearched'));
    expect(bloc, contains('_onPageRequested'));

    final useCases = File(
      p.join(
        project,
        'lib',
        'features',
        'products',
        'domain',
        'usecases',
        'get_products_list.dart',
      ),
    ).readAsStringSync();
    expect(useCases, contains('class SearchProducts'));
    expect(useCases, contains('class GetProductsPage'));
  });
}
