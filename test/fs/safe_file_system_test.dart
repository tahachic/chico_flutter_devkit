import 'dart:io';

import 'package:chico_flutter_devkit/chico_flutter_devkit.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tempRoot;
  late SafeFileSystem fs;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('devkit_fs_');
    fs = SafeFileSystem(projectRoot: tempRoot.path, createBackups: true);
  });

  tearDown(() async {
    if (tempRoot.existsSync()) {
      await tempRoot.delete(recursive: true);
    }
  });

  test('creates new files', () async {
    final result = await fs.applyWrites([
      const PlannedFileWrite(
        relativePath: 'lib/hello.dart',
        content: 'class Hello {}',
      ),
    ]);

    expect(result.createdCount, 1);
    expect(
      File(p.join(tempRoot.path, 'lib', 'hello.dart')).readAsStringSync(),
      'class Hello {}',
    );
  });

  test('dry-run does not write', () async {
    final result = await fs.applyWrites([
      const PlannedFileWrite(
        relativePath: 'lib/hello.dart',
        content: 'class Hello {}',
      ),
    ], dryRun: true);

    expect(result.dryRun, isTrue);
    expect(result.results.single.outcome, FileWriteOutcome.dryRun);
    expect(
      File(p.join(tempRoot.path, 'lib', 'hello.dart')).existsSync(),
      isFalse,
    );
  });

  test('refuses overwrite without force/mode', () async {
    final file = File(p.join(tempRoot.path, 'lib', 'hello.dart'));
    await file.parent.create(recursive: true);
    await file.writeAsString('old');

    expect(
      () => fs.applyWrites([
        const PlannedFileWrite(relativePath: 'lib/hello.dart', content: 'new'),
      ]),
      throwsA(isA<ExecutionException>()),
    );
  });

  test('overwrite with backup', () async {
    final file = File(p.join(tempRoot.path, 'lib', 'hello.dart'));
    await file.parent.create(recursive: true);
    await file.writeAsString('old');

    final result = await fs.applyWrites([
      const PlannedFileWrite(
        relativePath: 'lib/hello.dart',
        content: 'new',
        mode: FileWriteMode.overwrite,
      ),
    ]);

    expect(
      result.results.single.outcome,
      FileWriteOutcome.backedUpAndOverwritten,
    );
    expect(file.readAsStringSync(), 'new');
    expect(result.results.single.backupPath, isNotNull);
    expect(File(result.results.single.backupPath!).existsSync(), isTrue);
  });

  test('skipIfExists leaves file untouched', () async {
    final file = File(p.join(tempRoot.path, 'lib', 'hello.dart'));
    await file.parent.create(recursive: true);
    await file.writeAsString('old');

    final result = await fs.applyWrites([
      const PlannedFileWrite(
        relativePath: 'lib/hello.dart',
        content: 'new',
        mode: FileWriteMode.skipIfExists,
      ),
    ]);

    expect(result.skippedCount, 1);
    expect(file.readAsStringSync(), 'old');
  });

  test('blocks path traversal', () {
    expect(
      () => fs.resolvePath('../outside.dart'),
      throwsA(isA<InvalidUsageException>()),
    );
  });

  test('blocks absolute paths', () {
    expect(
      () => fs.resolvePath(p.join(tempRoot.path, 'lib', 'x.dart')),
      throwsA(isA<InvalidUsageException>()),
    );
  });
}
