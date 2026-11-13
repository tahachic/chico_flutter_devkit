import 'dart:io';

import 'package:chico_flutter_devkit/chico_flutter_devkit.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tempRoot;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('devkit_fs_rb_');
  });

  tearDown(() async {
    if (tempRoot.existsSync()) {
      await tempRoot.delete(recursive: true);
    }
  });

  test('rolls back earlier creates when a later write fails', () async {
    final fs = SafeFileSystem(
      projectRoot: tempRoot.path,
      createBackups: true,
      failAfterCommits: 1,
    );

    expect(
      () => fs.applyWrites([
        const PlannedFileWrite(
          relativePath: 'lib/a.dart',
          content: 'class A {}',
        ),
        const PlannedFileWrite(
          relativePath: 'lib/b.dart',
          content: 'class B {}',
        ),
      ]),
      throwsA(isA<ExecutionException>()),
    );

    expect(File(p.join(tempRoot.path, 'lib', 'a.dart')).existsSync(), isFalse);
    expect(File(p.join(tempRoot.path, 'lib', 'b.dart')).existsSync(), isFalse);
  });

  test('restores overwritten files from backup on batch failure', () async {
    final existing = File(p.join(tempRoot.path, 'lib', 'keep.dart'));
    await existing.parent.create(recursive: true);
    await existing.writeAsString('original');

    final fs = SafeFileSystem(
      projectRoot: tempRoot.path,
      createBackups: true,
      failAfterCommits: 1,
    );

    expect(
      () => fs.applyWrites([
        const PlannedFileWrite(
          relativePath: 'lib/keep.dart',
          content: 'mutated',
          mode: FileWriteMode.overwrite,
        ),
        const PlannedFileWrite(
          relativePath: 'lib/other.dart',
          content: 'other',
        ),
      ]),
      throwsA(isA<ExecutionException>()),
    );

    expect(existing.readAsStringSync(), 'original');
    expect(
      File(p.join(tempRoot.path, 'lib', 'other.dart')).existsSync(),
      isFalse,
    );
  });
}
