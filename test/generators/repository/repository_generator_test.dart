import 'dart:io';

import 'package:chico_flutter_devkit/chico_flutter_devkit.dart';
import 'package:chico_flutter_devkit/src/generators/feature/feature_generator.dart';
import 'package:chico_flutter_devkit/src/generators/repository/repository_generator.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../../support/project_fixtures.dart';

void main() {
  late Directory tempRoot;
  late Directory homeDir;
  late ConfigService configService;
  late GeneratorRunner runner;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('devkit_repo_');
    homeDir = await Directory.systemTemp.createTemp('devkit_repo_home_');
    configService = ConfigService(homeOverride: homeDir.path);
    await writeFlutterPubspec(tempRoot.path, chicoUi: true, chicoKit: true);
    await configService.initProjectConfig(
      projectRoot: tempRoot.path,
      config: DevKitConfigDefaults.create(projectName: 'shop_app'),
    );
    runner = GeneratorRunner(
      registry: GeneratorRegistry(
        generators: [FeatureGenerator(), RepositoryGenerator()],
      ),
      configService: configService,
    );
  });

  tearDown(() async {
    await tempRoot.delete(recursive: true);
    await homeDir.delete(recursive: true);
  });

  test('standalone repository without prerequisites fails safely', () async {
    expect(
      () => runner.run(
        projectRoot: tempRoot.path,
        generatorName: 'repository',
        targetName: 'Product',
        extra: {'crud': true, 'tests': false, 'remote': true},
      ),
      throwsA(
        isA<InvalidUsageException>().having(
          (e) => e.message,
          'message',
          contains('prerequisites are missing'),
        ),
      ),
    );
    expect(
      Directory(
        p.join(tempRoot.path, 'lib', 'features', 'product'),
      ).existsSync(),
      isFalse,
    );
  });

  test('repository generates into an existing feature', () async {
    await runner.run(
      projectRoot: tempRoot.path,
      generatorName: 'feature',
      targetName: 'products',
      extra: {'tests': false, 'remote': true},
    );

    // Remove repository files so we can regenerate them.
    final contract = File(
      p.join(
        tempRoot.path,
        'lib/features/products/domain/repositories/products_repository.dart',
      ),
    );
    final impl = File(
      p.join(
        tempRoot.path,
        'lib/features/products/data/repositories/products_repository_impl.dart',
      ),
    );
    if (contract.existsSync()) await contract.delete();
    if (impl.existsSync()) await impl.delete();

    final result = await runner.run(
      projectRoot: tempRoot.path,
      generatorName: 'repository',
      targetName: 'products',
      force: true,
      extra: {
        'feature': 'products',
        'crud': true,
        'tests': false,
        'remote': true,
      },
    );

    expect(result.writes.createdCount, greaterThanOrEqualTo(2));
    expect(contract.existsSync(), isTrue);
    expect(impl.existsSync(), isTrue);
    expect(
      contract.readAsStringSync(),
      contains('abstract interface class ProductsRepository'),
    );
  });
}
