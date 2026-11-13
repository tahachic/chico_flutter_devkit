import 'dart:io';

import 'package:chico_flutter_devkit/chico_flutter_devkit.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

final class _EchoGenerator extends BaseGenerator {
  @override
  String get name => 'echo';

  @override
  String get description => 'Test generator that writes one file.';

  @override
  Future<void> validate(GenerationContext context) async {
    if (context.targetName.snakeCase.isEmpty) {
      throw const InvalidUsageException('Name required');
    }
  }

  @override
  Future<GenerationResult> generate(GenerationContext context) {
    final content = context.templateEngine.render(
      'class {{className}} {}\n',
      context.templateVariables,
    );
    return commitWrites(
      context: context,
      writes: [
        PlannedFileWrite(
          relativePath: 'lib/${context.targetName.snakeCase}.dart',
          content: content,
        ),
      ],
      message: 'echoed',
    );
  }
}

void main() {
  late Directory tempRoot;
  late Directory homeDir;
  late ConfigService configService;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('devkit_gen_');
    homeDir = await Directory.systemTemp.createTemp('devkit_gen_home_');
    configService = ConfigService(homeOverride: homeDir.path);
  });

  tearDown(() async {
    await tempRoot.delete(recursive: true);
    await homeDir.delete(recursive: true);
  });

  test('registry rejects unknown generators', () {
    final registry = GeneratorRegistry();
    expect(
      () => registry.get('missing'),
      throwsA(isA<InvalidUsageException>()),
    );
  });

  test('runner generates files', () async {
    final registry = GeneratorRegistry(generators: [_EchoGenerator()]);
    final runner = GeneratorRunner(
      registry: registry,
      configService: configService,
    );

    final result = await runner.run(
      projectRoot: tempRoot.path,
      generatorName: 'echo',
      targetName: 'ProductDetails',
    );

    expect(result.writes.createdCount, 1);
    final file = File(p.join(tempRoot.path, 'lib', 'product_details.dart'));
    expect(file.existsSync(), isTrue);
    expect(file.readAsStringSync(), contains('class ProductDetails'));
  });

  test('runner supports dry-run', () async {
    final registry = GeneratorRegistry(generators: [_EchoGenerator()]);
    final runner = GeneratorRunner(
      registry: registry,
      configService: configService,
    );

    final result = await runner.run(
      projectRoot: tempRoot.path,
      generatorName: 'echo',
      targetName: 'Product',
      dryRun: true,
    );

    expect(result.isDryRun, isTrue);
    expect(
      File(p.join(tempRoot.path, 'lib', 'product.dart')).existsSync(),
      isFalse,
    );
  });

  test('CLI generate uses injected registry', () async {
    final app = CliApp(
      configService: configService,
      generatorRegistry: GeneratorRegistry(generators: [_EchoGenerator()]),
      projectRoot: tempRoot.path,
    );

    final code = await app.run(const [
      'generate',
      'echo',
      'OrderItem',
      '--dry-run',
    ]);
    expect(code, ExitCodes.success);
  });

  test('CLI generate without type reports usage error', () async {
    final app = CliApp(
      configService: configService,
      generatorRegistry: createDefaultGeneratorRegistry(),
      projectRoot: tempRoot.path,
    );

    final code = await app.run(const ['generate']);
    expect(code, ExitCodes.usage);
  });

  test('default registry includes Phase 3 generators', () {
    final registry = createDefaultGeneratorRegistry();
    expect(
      registry.names,
      containsAll([
        'feature',
        'model',
        'widget',
        'screen',
        'bloc',
        'cubit',
        'provider',
        'repository',
        'service',
        'enum',
        'extension',
        'test',
      ]),
    );
  });
}
