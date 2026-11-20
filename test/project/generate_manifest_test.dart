import 'dart:io';

import 'package:chico_flutter_devkit/chico_flutter_devkit.dart';
import 'package:chico_flutter_devkit/src/generators/model/model_generator.dart';
import 'package:chico_flutter_devkit/src/project/generate_manifest.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../support/project_fixtures.dart';

void main() {
  late Directory tempRoot;
  late Directory homeDir;
  late ConfigService configService;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('devkit_manifest_');
    homeDir = await Directory.systemTemp.createTemp('devkit_manifest_home_');
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

  test('records hashes and sync refreshes unchanged files', () async {
    final runner = GeneratorRunner(
      registry: GeneratorRegistry(generators: [ModelGenerator()]),
      configService: configService,
    );

    await runner.run(
      projectRoot: tempRoot.path,
      generatorName: 'model',
      targetName: 'Sku',
      extra: {'fields': 'id:String,code:String', 'tests': false},
    );

    final modelPath = p.join(tempRoot.path, 'lib', 'models', 'sku.dart');
    expect(File(modelPath).existsSync(), isTrue);
    final manifestFile = File(
      p.join(tempRoot.path, '.chico', 'generate_manifest.yaml'),
    );
    expect(manifestFile.existsSync(), isTrue);

    final original = File(modelPath).readAsStringSync();
    final manifest = GenerateManifest.load(tempRoot.path);
    expect(manifest.isUnchanged('lib/models/sku.dart'), isTrue);

    // Sync without edits should refresh.
    await runner.run(
      projectRoot: tempRoot.path,
      generatorName: 'model',
      targetName: 'Sku',
      sync: true,
      extra: {'fields': 'id:String,code:String', 'tests': false},
    );
    expect(File(modelPath).readAsStringSync(), original);

    // User edit → sync refuses.
    await File(modelPath).writeAsString('$original\n// user edit\n');
    await expectLater(
      () => runner.run(
        projectRoot: tempRoot.path,
        generatorName: 'model',
        targetName: 'Sku',
        sync: true,
        extra: {'fields': 'id:String,code:String', 'tests': false},
      ),
      throwsA(
        isA<ExecutionException>().having(
          (e) => e.message,
          'message',
          contains('user-edited'),
        ),
      ),
    );
  });

  test('corrupt manifest fails closed', () async {
    final file = File(
      p.join(tempRoot.path, '.chico', 'generate_manifest.yaml'),
    );
    await file.parent.create(recursive: true);
    await file.writeAsString('files: "not-a-map"\n');
    expect(
      () => GenerateManifest.load(tempRoot.path),
      throwsA(isA<ExecutionException>()),
    );
  });
}
