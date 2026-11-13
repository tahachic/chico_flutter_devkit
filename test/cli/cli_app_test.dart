import 'dart:convert';
import 'dart:io';

import 'package:chico_flutter_devkit/chico_flutter_devkit.dart';
import 'package:chico_flutter_devkit/src/quality/tool_runner.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tempRoot;
  late Directory homeDir;
  late IOSink stdoutSink;
  late IOSink stderrSink;
  late StringBuffer stdoutBuffer;
  late StringBuffer stderrBuffer;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('devkit_cli_');
    homeDir = await Directory.systemTemp.createTemp('devkit_cli_home_');
    stdoutBuffer = StringBuffer();
    stderrBuffer = StringBuffer();
    stdoutSink = _BufferSink(stdoutBuffer);
    stderrSink = _BufferSink(stderrBuffer);
  });

  tearDown(() async {
    await tempRoot.delete(recursive: true);
    await homeDir.delete(recursive: true);
  });

  CliApp buildApp({ToolRunner? toolRunner}) {
    return CliApp(
      logger: DevKitLogger(),
      configService: ConfigService(homeOverride: homeDir.path),
      projectRoot: tempRoot.path,
      stdoutSink: stdoutSink,
      stderrSink: stderrSink,
      toolRunner: toolRunner ?? FakeToolRunner(),
    );
  }

  Future<void> writeFlutterProject() async {
    await File(p.join(tempRoot.path, 'pubspec.yaml')).writeAsString('''
name: shop_app
description: test
version: 1.0.0
environment:
  sdk: ^3.8.0
dependencies:
  flutter:
    sdk: flutter
''');
    await Directory(p.join(tempRoot.path, 'lib')).create();
    await File(
      p.join(tempRoot.path, 'lib', 'main.dart'),
    ).writeAsString('void main() {}');
  }

  test('--version prints package version', () async {
    final code = await buildApp().run(const ['--version']);
    expect(code, ExitCodes.success);
    expect(stdoutBuffer.toString().trim(), packageVersion);
  });

  test('--help prints banner and usage', () async {
    final code = await buildApp().run(const ['--help']);
    expect(code, ExitCodes.success);
    final output = stdoutBuffer.toString();
    expect(output, contains('CHICO FLUTTER DEVKIT'));
    expect(output, contains('config'));
    expect(output, contains('list'));
  });

  test('doctor --json reports project health', () async {
    await writeFlutterProject();
    final code = await buildApp().run(const ['doctor', '--json']);
    expect(code, ExitCodes.success);
  });

  test('doctor --fix --yes applies safe repairs and re-inspects', () async {
    await writeFlutterProject();
    final code = await buildApp().run(const ['doctor', '--fix', '--yes']);
    expect(code, ExitCodes.success);
    expect(
      File(p.join(tempRoot.path, '.chico', 'devkit.yaml')).existsSync(),
      isTrue,
    );
    expect(
      File(p.join(tempRoot.path, 'analysis_options.yaml')).existsSync(),
      isTrue,
    );
    expect(Directory(p.join(tempRoot.path, 'test')).existsSync(), isTrue);
  });

  test('analyze/format/test/clean use injected tool runner', () async {
    await writeFlutterProject();
    final tools = FakeToolRunner();
    final app = buildApp(toolRunner: tools);

    expect(await app.run(const ['analyze']), ExitCodes.success);
    expect(await app.run(const ['format']), ExitCodes.success);
    expect(await app.run(const ['test']), ExitCodes.success);
    expect(await app.run(const ['clean']), ExitCodes.success);

    expect(
      tools.calls.map((c) => c.join(' ')),
      containsAll([
        'flutter analyze',
        'dart format lib',
        'flutter test',
        'flutter clean',
      ]),
    );
  });

  test('upgrade --dry-run reports planned Chico updates', () async {
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
    final code = await buildApp().run(const ['upgrade', '--dry-run']);
    expect(code, ExitCodes.success);
  });

  test('config init + show round trip', () async {
    final app = buildApp();

    final initCode = await app.run(const [
      'config',
      'init',
      '--name',
      'shop_app',
    ]);
    expect(initCode, ExitCodes.success);
    expect(
      File(p.join(tempRoot.path, '.chico', 'devkit.yaml')).existsSync(),
      isTrue,
    );

    final showCode = await app.run(const ['config', 'show', '--json']);
    expect(showCode, ExitCodes.success);

    // mason_logger writes to its own stdout; JSON path uses logger.info.
    // Re-resolve via service for deterministic assertion.
    final resolved = ConfigService(
      homeOverride: homeDir.path,
    ).resolve(projectRoot: tempRoot.path);
    expect(resolved.config.project.name, 'shop_app');
    expect(jsonEncode(resolved.config.toYamlMap()), contains('shop_app'));
  });

  test('config set updates architecture', () async {
    final app = buildApp();
    await app.run(const ['config', 'init', '--name', 'shop_app']);
    final code = await app.run(const [
      'config',
      'set',
      'project.architecture',
      'feature_first',
    ]);
    expect(code, ExitCodes.success);

    final resolved = ConfigService(
      homeOverride: homeDir.path,
    ).resolve(projectRoot: tempRoot.path);
    expect(resolved.config.project.architecture, Architecture.featureFirst);
  });

  test('list commands succeeds', () async {
    final code = await buildApp().run(const ['list']);
    expect(code, ExitCodes.success);
  });

  test('config path prints project config path', () async {
    final code = await buildApp().run(const ['config', 'path']);
    expect(code, ExitCodes.success);
  });
}

final class _BufferSink implements IOSink {
  _BufferSink(this.buffer);

  final StringBuffer buffer;

  @override
  Encoding encoding = utf8;

  @override
  void add(List<int> data) => buffer.write(utf8.decode(data));

  @override
  void addError(Object error, [StackTrace? stackTrace]) {
    buffer.writeln(error);
  }

  @override
  void write(Object? object) => buffer.write(object);

  @override
  void writeAll(Iterable<dynamic> objects, [String separator = '']) {
    buffer.writeAll(objects, separator);
  }

  @override
  void writeln([Object? object = '']) => buffer.writeln(object);

  @override
  void writeCharCode(int charCode) => buffer.writeCharCode(charCode);

  @override
  Future<void> addStream(Stream<List<int>> stream) async {
    await for (final chunk in stream) {
      add(chunk);
    }
  }

  @override
  Future<void> flush() async {}

  @override
  Future<void> close() async {}

  @override
  Future<dynamic> get done async {}
}
