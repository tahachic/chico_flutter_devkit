import 'dart:io';

import 'package:path/path.dart' as p;

import '../../config/models.dart';
import '../../pubspec/pubspec_editor.dart';

/// Resolves UI import preferences from Chico config / Material UI migration.
abstract final class UiImports {
  static const materialUiPackage = 'material_ui';
  static const materialUiConstraint = '^1.0.0';
  static const cupertinoUiPackage = 'cupertino_ui';
  static const cupertinoUiConstraint = '^1.0.0';

  /// Flutter 3.47+ standalone Material package (required to silence 3.50
  /// `deprecated_member_use` infos for `package:flutter/material.dart`).
  static String materialImport({required bool useMaterialUi}) => useMaterialUi
      ? "import 'package:$materialUiPackage/$materialUiPackage.dart';"
      : "import 'package:flutter/material.dart';";

  static String packageImport(
    DevKitConfig config, {
    bool useMaterialUi = false,
  }) {
    if (config.chico.kit.enabled) {
      return "import 'package:flutter/widgets.dart';\n"
          "import 'package:chico_kit/chico_kit.dart';";
    }
    if (config.chico.ui.enabled) {
      return "import 'package:flutter/widgets.dart';\n"
          "import 'package:chico_ui/chico_ui.dart';";
    }
    return materialImport(useMaterialUi: useMaterialUi);
  }

  static bool useChico(DevKitConfig config) =>
      config.chico.ui.enabled || config.chico.kit.enabled;

  /// True when the project already depends on `material_ui`.
  static Future<bool> projectUsesMaterialUi(String projectRoot) async {
    final pubspec = File(p.join(projectRoot, 'pubspec.yaml'));
    if (!pubspec.existsSync()) return false;
    try {
      final deps = await PubspecEditor.forProject(projectRoot).listDependencies();
      return deps.containsKey(materialUiPackage);
    } catch (_) {
      return pubspec.readAsStringSync().contains('$materialUiPackage:');
    }
  }
}
