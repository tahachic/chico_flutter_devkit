import 'dart:io';

import 'package:chico_flutter_devkit/src/pubspec/pubspec_editor.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test('adds dependency to pubspec', () async {
    final dir = await Directory.systemTemp.createTemp('devkit_pub_');
    addTearDown(() async => dir.delete(recursive: true));

    final file = File(p.join(dir.path, 'pubspec.yaml'));
    await file.writeAsString('''
name: demo
environment:
  sdk: ^3.8.0
dependencies:
  flutter:
    sdk: flutter
''');

    final editor = PubspecEditor(file);
    final changed = await editor.ensureDependency(
      packageName: 'chico_ui',
      constraint: '^1.7.0',
    );
    expect(changed, isTrue);
    expect(await editor.hasDependency('chico_ui'), isTrue);
    expect(file.readAsStringSync(), contains('chico_ui: ^1.7.0'));
  });
}
