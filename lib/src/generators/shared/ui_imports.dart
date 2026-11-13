import '../../config/models.dart';

/// Resolves UI import preferences from Chico config.
abstract final class UiImports {
  static String packageImport(DevKitConfig config) {
    if (config.chico.kit.enabled) {
      return "import 'package:flutter/widgets.dart';\n"
          "import 'package:chico_kit/chico_kit.dart';";
    }
    if (config.chico.ui.enabled) {
      return "import 'package:flutter/widgets.dart';\n"
          "import 'package:chico_ui/chico_ui.dart';";
    }
    return "import 'package:flutter/material.dart';";
  }

  static bool useChico(DevKitConfig config) =>
      config.chico.ui.enabled || config.chico.kit.enabled;
}
