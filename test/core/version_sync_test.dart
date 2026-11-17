import 'dart:io';

import 'package:chico_flutter_devkit/src/core/version.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

/// Guards against pub.dev README / CLI version drift.
///
/// Shipping docs must not hardcode `1.0.0-dev.*`; the single source of truth is
/// `pubspec.yaml` + `lib/src/core/version.dart`.
void main() {
  final root = _packageRoot();

  test('packageVersion matches pubspec.yaml', () {
    final pubspec = File(p.join(root, 'pubspec.yaml'));
    final yaml = loadYaml(pubspec.readAsStringSync()) as YamlMap;
    final pubspecVersion = yaml['version'] as String;
    expect(
      packageVersion,
      pubspecVersion,
      reason:
          'Bump lib/src/core/version.dart together with pubspec.yaml '
          '(see doc/RELEASE.md).',
    );
  });

  test('shipping docs do not hardcode prerelease version numbers', () {
    final hardcoded = RegExp(r'1\.0\.0-dev\.\d+');
    final files = <String>[
      'README.md',
      'OPENAPI_SUPPORT_MATRIX.md',
      'example/README.md',
      'doc/GETTING_STARTED.md',
      'doc/COMMAND_REFERENCE.md',
      'doc/CREATE_APP.md',
      'doc/COOKBOOK.md',
      'doc/CONFIGURATION.md',
      'doc/ARCHITECTURE.md',
      'doc/GENERATOR_GUIDE.md',
      'doc/TROUBLESHOOTING.md',
      'doc/OPENAPI.md',
      'doc/RELEASE.md',
      'doc/TEMPLATE_DEVELOPMENT.md',
      'doc/ANDROID.md',
    ];

    final offenders = <String>[];
    for (final relative in files) {
      final file = File(p.join(root, relative));
      if (!file.existsSync()) continue;
      final text = file.readAsStringSync();
      final matches = hardcoded.allMatches(text).map((m) => m.group(0)!);
      for (final match in matches) {
        offenders.add('$relative → $match');
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Do not hardcode package versions in shipping docs (they drift on '
          'pub.dev). Use `devkit --version` / pub.dev instead. Offenders: '
          '${offenders.join(', ')}',
    );
  });
}

String _packageRoot() {
  var dir = Directory.current;
  while (true) {
    if (File(p.join(dir.path, 'pubspec.yaml')).existsSync() &&
        File(
          p.join(dir.path, 'lib', 'src', 'core', 'version.dart'),
        ).existsSync()) {
      return dir.path;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) {
      fail('Could not locate package root from ${Directory.current.path}');
    }
    dir = parent;
  }
}
