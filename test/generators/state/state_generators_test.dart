import 'dart:io';

import 'package:chico_flutter_devkit/chico_flutter_devkit.dart';
import 'package:chico_flutter_devkit/src/generators/state/bloc_generator.dart';
import 'package:chico_flutter_devkit/src/generators/state/cubit_generator.dart';
import 'package:chico_flutter_devkit/src/generators/state/provider_generator.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tempRoot;
  late Directory homeDir;
  late ConfigService configService;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('devkit_state_');
    homeDir = await Directory.systemTemp.createTemp('devkit_state_home_');
    configService = ConfigService(homeOverride: homeDir.path);
    await configService.initProjectConfig(
      projectRoot: tempRoot.path,
      config: DevKitConfigDefaults.create(projectName: 'shop_app'),
    );
  });

  tearDown(() async {
    await tempRoot.delete(recursive: true);
    await homeDir.delete(recursive: true);
  });

  test('bloc generator writes event/state/bloc', () async {
    final runner = GeneratorRunner(
      registry: GeneratorRegistry(generators: [BlocGenerator()]),
      configService: configService,
    );
    final result = await runner.run(
      projectRoot: tempRoot.path,
      generatorName: 'bloc',
      targetName: 'Products',
      extra: {'tests': false},
    );
    expect(result.writes.createdCount, 3);
    expect(
      File(
        p.join(
          tempRoot.path,
          'lib',
          'presentation',
          'bloc',
          'products_bloc.dart',
        ),
      ).existsSync(),
      isTrue,
    );
  });

  test('cubit generator writes cubit files', () async {
    final runner = GeneratorRunner(
      registry: GeneratorRegistry(generators: [CubitGenerator()]),
      configService: configService,
    );
    await runner.run(
      projectRoot: tempRoot.path,
      generatorName: 'cubit',
      targetName: 'Cart',
      extra: {'tests': false},
    );
    expect(
      File(
        p.join(
          tempRoot.path,
          'lib',
          'presentation',
          'cubit',
          'cart_cubit.dart',
        ),
      ).existsSync(),
      isTrue,
    );
  });

  test('provider generator can emit riverpod', () async {
    final runner = GeneratorRunner(
      registry: GeneratorRegistry(generators: [ProviderGenerator()]),
      configService: configService,
    );
    await runner.run(
      projectRoot: tempRoot.path,
      generatorName: 'provider',
      targetName: 'Orders',
      extra: {'tests': false, 'state': 'riverpod'},
    );
    final source = File(
      p.join(
        tempRoot.path,
        'lib',
        'presentation',
        'providers',
        'orders_providers.dart',
      ),
    ).readAsStringSync();
    expect(source, contains('flutter_riverpod'));
  });
}
