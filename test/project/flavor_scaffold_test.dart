import 'dart:io';

import 'package:chico_flutter_devkit/src/project/flavor_scaffold.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tempRoot;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('devkit_flavor_');
  });

  tearDown(() async {
    await tempRoot.delete(recursive: true);
  });

  test('patches Android groovy build.gradle with productFlavors', () async {
    final gradle = File(
      p.join(tempRoot.path, 'android', 'app', 'build.gradle'),
    );
    await gradle.parent.create(recursive: true);
    await gradle.writeAsString('''
android {
    namespace "com.example.app"
    defaultConfig {
        applicationId "com.example.app"
        minSdk 24
    }
}
''');

    final touched = await FlavorScaffold.apply(tempRoot.path);
    expect(touched, contains('android/app/build.gradle'));
    final out = gradle.readAsStringSync();
    expect(out, contains('productFlavors'));
    expect(out, contains('dev {'));
    expect(out, contains('staging {'));
    expect(out, contains('prod {'));
  });

  test('writes iOS DevKit xcconfigs when ios/Flutter exists', () async {
    await Directory(
      p.join(tempRoot.path, 'ios', 'Flutter'),
    ).create(recursive: true);

    final touched = await FlavorScaffold.apply(tempRoot.path);
    expect(touched, contains('ios/Flutter/Devkit-Dev.xcconfig'));
    expect(touched, contains('ios/Flutter/DEVKIT_FLAVORS.md'));
    expect(
      File(
        p.join(tempRoot.path, 'ios', 'Flutter', 'Devkit-Dev.xcconfig'),
      ).readAsStringSync(),
      contains('ENV=dev'),
    );
  });
}
