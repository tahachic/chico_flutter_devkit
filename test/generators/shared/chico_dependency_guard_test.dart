import 'dart:io';

import 'package:chico_flutter_devkit/chico_flutter_devkit.dart';
import 'package:chico_flutter_devkit/src/generators/shared/chico_dependency_guard.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../../support/project_fixtures.dart';

void main() {
  late Directory tempRoot;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('devkit_chico_guard_');
  });

  tearDown(() async {
    await tempRoot.delete(recursive: true);
  });

  GenerationContext context({
    required DevKitConfig config,
    Map<String, Object?> extra = const {},
    bool dryRun = false,
  }) {
    return GenerationContext(
      projectRoot: tempRoot.path,
      config: config,
      targetName: NameConverter.parse('demo'),
      fileSystem: SafeFileSystem(projectRoot: tempRoot.path),
      templateEngine: const TemplateEngine(),
      dryRun: dryRun,
      extra: extra,
    );
  }

  test('passes when required Chico deps are present and compatible', () async {
    await writeFlutterPubspec(tempRoot.path, chicoUi: true, chicoKit: true);
    await ChicoDependencyGuard.ensure(
      context: context(config: DevKitConfigDefaults.create()),
    );
  });

  test('fails clearly when deps are missing', () async {
    await writeFlutterPubspec(tempRoot.path);
    expect(
      () => ChicoDependencyGuard.ensure(
        context: context(config: DevKitConfigDefaults.create()),
      ),
      throwsA(
        isA<InvalidUsageException>().having(
          (e) => e.message,
          'message',
          contains('Missing Chico'),
        ),
      ),
    );
  });

  test('fails when declared constraint is incompatible', () async {
    await File(p.join(tempRoot.path, 'pubspec.yaml')).writeAsString('''
name: shop_app
environment:
  sdk: ^3.8.0
dependencies:
  flutter:
    sdk: flutter
  chico_ui: ^0.1.0
  chico_kit: ^0.1.0
''');
    expect(
      () => ChicoDependencyGuard.ensure(
        context: context(config: DevKitConfigDefaults.create()),
      ),
      throwsA(
        isA<InvalidUsageException>().having(
          (e) => e.message,
          'message',
          contains('Incompatible Chico'),
        ),
      ),
    );
  });

  test('fails on malformed version constraints', () async {
    await File(p.join(tempRoot.path, 'pubspec.yaml')).writeAsString('''
name: shop_app
environment:
  sdk: ^3.8.0
dependencies:
  flutter:
    sdk: flutter
  chico_ui: 'not a version'
  chico_kit: ^1.4.0
''');
    expect(
      () => ChicoDependencyGuard.ensure(
        context: context(config: DevKitConfigDefaults.create()),
      ),
      throwsA(
        isA<InvalidUsageException>().having(
          (e) => e.details,
          'details',
          contains('malformed'),
        ),
      ),
    );
  });

  test('evaluateCompatibility accepts intersecting constraints', () {
    final result = ChicoDependencyGuard.evaluateCompatibility(
      packageName: 'chico_ui',
      declaredConstraint: '^1.7.0',
      requiredConstraint: '^1.7.0',
    );
    expect(result.ok, isTrue);
  });

  test('dry-run never mutates pubspec even with addMissingChico', () async {
    await writeFlutterPubspec(tempRoot.path);
    final before = File(
      p.join(tempRoot.path, 'pubspec.yaml'),
    ).readAsStringSync();
    expect(
      () => ChicoDependencyGuard.ensure(
        context: context(
          config: DevKitConfigDefaults.create(),
          dryRun: true,
          extra: {'addMissingChico': true},
        ),
      ),
      throwsA(isA<InvalidUsageException>()),
    );
    expect(
      File(p.join(tempRoot.path, 'pubspec.yaml')).readAsStringSync(),
      before,
    );
  });

  test('addMissingChico installs only missing packages', () async {
    await writeFlutterPubspec(tempRoot.path);
    await ChicoDependencyGuard.ensure(
      context: context(
        config: DevKitConfigDefaults.create(),
        extra: {'addMissingChico': true},
      ),
    );
    final text = File(p.join(tempRoot.path, 'pubspec.yaml')).readAsStringSync();
    expect(text, contains('chico_ui'));
    expect(text, contains('chico_kit'));
  });

  test('addMissingChico does not overwrite existing constraints', () async {
    await File(p.join(tempRoot.path, 'pubspec.yaml')).writeAsString('''
name: shop_app
environment:
  sdk: ^3.8.0
dependencies:
  flutter:
    sdk: flutter
  chico_ui: ^1.8.0
''');
    // kit missing; ui present with compatible constraint — should only add kit
    await ChicoDependencyGuard.ensure(
      context: context(
        config: DevKitConfigDefaults.create(),
        extra: {'addMissingChico': true},
      ),
    );
    final text = File(p.join(tempRoot.path, 'pubspec.yaml')).readAsStringSync();
    expect(text, contains('chico_ui: ^1.8.0'));
    expect(text, contains('chico_kit'));
  });

  test('invalid pubspec is rejected', () {
    expect(ChicoDependencyGuard.looksLikeValidPubspec('not: yaml: ['), isFalse);
  });
}
