import 'dart:io';

import 'package:path/path.dart' as p;

/// Writes ENV flavor wiring for Android / iOS (logic only — no UI).
abstract final class FlavorScaffold {
  /// Applies productFlavors / xcconfigs when platform folders exist.
  /// Returns relative paths written or patched.
  static Future<List<String>> apply(String projectRoot) async {
    final root = p.normalize(projectRoot);
    final touched = <String>[];

    final android = await _patchAndroid(root);
    if (android != null) touched.add(android);

    final ios = await _writeIosXcconfigs(root);
    touched.addAll(ios);

    return touched;
  }

  static Future<String?> _patchAndroid(String root) async {
    final kts = File(p.join(root, 'android', 'app', 'build.gradle.kts'));
    final groovy = File(p.join(root, 'android', 'app', 'build.gradle'));
    final file = kts.existsSync()
        ? kts
        : groovy.existsSync()
        ? groovy
        : null;
    if (file == null) return null;

    var source = await file.readAsString();
    if (source.contains('productFlavors') && source.contains('create("dev")')) {
      return null;
    }
    if (source.contains('productFlavors') && source.contains('dev {')) {
      return null;
    }

    final isKts = file.path.endsWith('.kts');
    final block = isKts ? _androidKtsFlavors : _androidGroovyFlavors;

    if (source.contains('defaultConfig')) {
      // Insert after defaultConfig { ... } closing — append before closing of android {
      final marker = isKts ? 'defaultConfig {' : 'defaultConfig {';
      final idx = source.indexOf(marker);
      if (idx >= 0) {
        final insertAt = _endOfBraceBlock(source, idx);
        if (insertAt > 0) {
          source =
              '${source.substring(0, insertAt)}\n$block${source.substring(insertAt)}';
          await file.writeAsString(source);
          return p.relative(file.path, from: root).replaceAll(r'\', '/');
        }
      }
    }

    // Fallback: append flavor snippet file for the user to merge.
    final snippet = File(
      p.join(root, 'android', 'app', 'devkit_flavors.gradle'),
    );
    await snippet.parent.create(recursive: true);
    await snippet.writeAsString(_androidGroovyFlavors);
    return 'android/app/devkit_flavors.gradle';
  }

  static Future<List<String>> _writeIosXcconfigs(String root) async {
    final flutterDir = Directory(p.join(root, 'ios', 'Flutter'));
    if (!flutterDir.existsSync()) return const [];

    final written = <String>[];
    for (final env in ['dev', 'staging', 'prod']) {
      final relative =
          'ios/Flutter/Devkit-${env[0].toUpperCase()}${env.substring(1)}.xcconfig';
      final file = File(p.join(root, relative));
      await file.writeAsString('''
#include? "Pods/Target Support Files/Pods-Runner/Pods-Runner.debug.xcconfig"
#include "Generated.xcconfig"
// DevKit flavor — select this xcconfig in Xcode or pass --dart-define=ENV=$env
DART_DEFINES=\$(DART_DEFINES),ENV=$env
''');
      written.add(relative);
    }
    final readme = File(p.join(root, 'ios', 'Flutter', 'DEVKIT_FLAVORS.md'));
    await readme.writeAsString('''
# DevKit ENV flavors (iOS)

Xcconfigs: `Devkit-Dev.xcconfig`, `Devkit-Staging.xcconfig`, `Devkit-Prod.xcconfig`.

Run from CLI (any host):

```bash
flutter run --dart-define=ENV=dev
flutter run --dart-define=ENV=staging
flutter run --dart-define=ENV=prod
```

Wire the xcconfig into your Xcode scheme when you want IDE-native flavors.
''');
    written.add('ios/Flutter/DEVKIT_FLAVORS.md');
    return written;
  }

  static int _endOfBraceBlock(String source, int openKeywordIndex) {
    final open = source.indexOf('{', openKeywordIndex);
    if (open < 0) return -1;
    var depth = 0;
    for (var i = open; i < source.length; i++) {
      final c = source[i];
      if (c == '{') depth++;
      if (c == '}') {
        depth--;
        if (depth == 0) return i + 1;
      }
    }
    return -1;
  }

  // No resValue — Flutter Gradle disables custom resource values in flavors.
  // ENV is carried by --dart-define=ENV=… (AppConfig.current).
  static const _androidKtsFlavors = '''
    flavorDimensions += "env"
    productFlavors {
        create("dev") {
            dimension = "env"
            applicationIdSuffix = ".dev"
        }
        create("staging") {
            dimension = "env"
            applicationIdSuffix = ".staging"
        }
        create("prod") {
            dimension = "env"
        }
    }
''';

  static const _androidGroovyFlavors = '''
    flavorDimensions "env"
    productFlavors {
        dev {
            dimension "env"
            applicationIdSuffix ".dev"
        }
        staging {
            dimension "env"
            applicationIdSuffix ".staging"
        }
        prod {
            dimension "env"
        }
    }
''';
}
