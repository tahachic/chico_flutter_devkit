import 'dart:io';

import 'package:chico_flutter_devkit/chico_flutter_devkit.dart';
import 'package:chico_flutter_devkit/src/quality/quality_service.dart';
import 'package:chico_flutter_devkit/src/quality/tool_runner.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tempRoot;
  late FakeToolRunner toolRunner;
  late QualityService service;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('devkit_quality_');
    toolRunner = FakeToolRunner();
    service = QualityService(toolRunner: toolRunner);
    await File(p.join(tempRoot.path, 'pubspec.yaml')).writeAsString('''
name: shop_app
description: test
version: 1.0.0
environment:
  sdk: ^3.8.0
dependencies:
  flutter:
    sdk: flutter
  chico_ui: ^1.0.0
''');
  });

  tearDown(() async {
    await tempRoot.delete(recursive: true);
  });

  test('analyze/format/test/clean invoke expected tools', () async {
    await Directory(p.join(tempRoot.path, 'lib')).create();
    await Directory(p.join(tempRoot.path, 'test')).create();

    await service.analyze(tempRoot.path, fatalInfos: true);
    await service.format(tempRoot.path, setExitIfChanged: true);
    await service.test(tempRoot.path, coverage: true);
    await service.clean(tempRoot.path);

    expect(
      toolRunner.calls.map((c) => c.join(' ')),
      containsAll([
        'flutter analyze --fatal-infos',
        'dart format --set-exit-if-changed lib test',
        'flutter test --coverage',
        'flutter clean',
      ]),
    );
  });

  test('upgrade updates managed Chico constraints', () async {
    toolRunner.stub(
      'flutter pub get',
      const ToolRunResult(
        exitCode: 0,
        stdout: 'Got dependencies!',
        stderr: '',
        command: ['flutter', 'pub', 'get'],
      ),
    );

    final dry = await service.upgrade(tempRoot.path, dryRun: true);
    expect(dry.planned.single, contains('chico_ui'));
    expect(dry.applied, isEmpty);

    final applied = await service.upgrade(tempRoot.path);
    expect(applied.applied, ['chico_ui']);
    expect(
      File(p.join(tempRoot.path, 'pubspec.yaml')).readAsStringSync(),
      contains(DefaultChicoVersions.ui),
    );
    expect(toolRunner.calls.last, ['flutter', 'pub', 'get']);
  });

  test('throws when pubspec is missing', () async {
    final empty = await Directory.systemTemp.createTemp(
      'devkit_quality_empty_',
    );
    addTearDown(() async => empty.delete(recursive: true));
    expect(
      () => service.analyze(empty.path),
      throwsA(isA<ExecutionException>()),
    );
  });
}
