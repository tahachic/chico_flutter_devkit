import 'dart:io';

import 'package:path/path.dart' as p;

/// Writes a minimal Flutter pubspec suitable for generator unit tests.
Future<void> writeFlutterPubspec(
  String projectRoot, {
  String name = 'shop_app',
  bool chicoUi = false,
  bool chicoKit = false,
  bool chicoServices = false,
}) async {
  final deps = StringBuffer('''
  flutter:
    sdk: flutter
''');
  if (chicoUi || chicoKit || chicoServices) {
    deps.writeln('  chico_ui: ^1.7.0');
  }
  if (chicoKit || chicoServices) {
    deps.writeln('  chico_kit: ^1.4.0');
  }
  if (chicoServices) {
    deps.writeln('  chico_services: ^1.4.0');
  }

  await File(p.join(projectRoot, 'pubspec.yaml')).writeAsString('''
name: $name
description: test fixture
version: 1.0.0+1
environment:
  sdk: ^3.8.0
dependencies:
$deps
dev_dependencies:
  flutter_test:
    sdk: flutter
flutter:
  uses-material-design: true
''');
}
