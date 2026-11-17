import 'dart:io';

import 'package:chico_flutter_devkit/chico_flutter_devkit.dart';
import 'package:path/path.dart' as p;

/// Defaults with Chico ui/kit/services enabled (create is Material-first).
DevKitConfig chicoEnabledConfig({String projectName = 'shop_app'}) {
  final base = DevKitConfigDefaults.create(projectName: projectName);
  return base.copyWith(
    chico: base.chico.copyWith(
      ui: base.chico.ui.copyWith(enabled: true),
      kit: base.chico.kit.copyWith(enabled: true),
      services: base.chico.services.copyWith(enabled: true),
    ),
  );
}

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
    deps.writeln('  chico_services: ^1.4.1');
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
