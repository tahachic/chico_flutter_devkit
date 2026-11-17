import 'dart:io';

import 'package:path/path.dart' as p;

import '../../config/models.dart';
import 'ui_imports.dart';

/// Helpers for tests emitted into consumer Flutter apps.
abstract final class GeneratedTestSupport {
  /// Prefer `flutter_test` in Flutter projects (apps rarely depend on `test`).
  static String unitTestImport({required bool isFlutter}) {
    return isFlutter
        ? "import 'package:flutter_test/flutter_test.dart';"
        : "import 'package:test/test.dart';";
  }

  static bool isFlutterProject(String projectRoot) {
    final pubspec = File(p.join(projectRoot, 'pubspec.yaml'));
    if (!pubspec.existsSync()) return false;
    final text = pubspec.readAsStringSync();
    return text.contains('\n  flutter:') ||
        text.contains('\nflutter:') ||
        text.contains('sdk: flutter');
  }

  /// Imports for a widget/screen smoke test (ChicoApp vs MaterialApp).
  static String widgetHarnessImports({
    required DevKitConfig config,
    required String underTestImport,
    bool useMaterialUi = false,
  }) {
    if (UiImports.useChico(config)) {
      final chico = config.chico.kit.enabled
          ? "import 'package:chico_kit/chico_kit.dart';"
          : "import 'package:chico_ui/chico_ui.dart';";
      return "import 'package:flutter_test/flutter_test.dart';\n"
          '$chico\n'
          "import '$underTestImport';";
    }
    return '${UiImports.materialImport(useMaterialUi: useMaterialUi)}\n'
        "import 'package:flutter_test/flutter_test.dart';\n"
        "import '$underTestImport';";
  }
}
