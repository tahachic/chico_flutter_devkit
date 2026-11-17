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

  test('ensures flutter_localizations sdk dep and generate flag', () async {
    final dir = await Directory.systemTemp.createTemp('devkit_pub_l10n_');
    addTearDown(() async => dir.delete(recursive: true));

    final file = File(p.join(dir.path, 'pubspec.yaml'));
    await file.writeAsString('''
name: demo
environment:
  sdk: ^3.8.0
dependencies:
  flutter:
    sdk: flutter
flutter:
  uses-material-design: true
''');

    final editor = PubspecEditor(file);
    expect(await editor.ensureSdkDependency('flutter_localizations'), isTrue);
    expect(
      await editor.ensureDependency(packageName: 'intl', constraint: 'any'),
      isTrue,
    );
    expect(await editor.ensureFlutterGenerate(), isTrue);
    final text = file.readAsStringSync();
    expect(text, contains('flutter_localizations'));
    expect(text, contains('sdk: flutter'));
    expect(text, contains('intl: any'));
    expect(text, contains('generate: true'));
  });
}
