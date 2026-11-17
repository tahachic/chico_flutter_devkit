import 'dart:io';

import 'package:path/path.dart' as p;

/// Rewrites `flutter gen-l10n` output so Material/Cupertino delegates come from
/// standalone packages (required for `analyze --fatal-infos` on Flutter 3.50+).
abstract final class MaterialUiL10nPatch {
  static const relativePath = 'lib/l10n/app_localizations.dart';

  /// Returns `true` when the file was modified.
  static Future<bool> apply(String projectRoot) async {
    final file = File(p.join(projectRoot, relativePath));
    if (!file.existsSync()) return false;

    var source = await file.readAsString();
    final original = source;

    if (!source.contains("import 'package:material_ui/material_ui.dart';")) {
      source = source.replaceFirstMapped(
        RegExp(r'^import .*;\s*$', multiLine: true),
        (match) =>
            "${match.group(0)}\nimport 'package:material_ui/material_ui.dart';",
      );
    }

    // Avoid ambiguous GlobalMaterialLocalizations from flutter_localizations.
    source = source.replaceAllMapped(
      RegExp(
        r"import 'package:flutter_localizations/flutter_localizations\.dart';",
      ),
      (_) =>
          "import 'package:flutter_localizations/flutter_localizations.dart' "
          'show GlobalWidgetsLocalizations;',
    );

    // Replace the classic three Global* delegates with material_ui's combined
    // list (keeps the app's own AppLocalizations delegate entry).
    final classicDelegates = RegExp(
      r'(static const List<LocalizationsDelegate<dynamic>>\s+'
      r'localizationsDelegates\s*=\s*\[)'
      r'(.*?)'
      r'(GlobalMaterialLocalizations\.delegate\s*,\s*'
      r'GlobalCupertinoLocalizations\.delegate\s*,\s*'
      r'GlobalWidgetsLocalizations\.delegate\s*,?\s*)'
      r'(\];)',
      multiLine: true,
      dotAll: true,
    );

    if (classicDelegates.hasMatch(source)) {
      source = source.replaceFirstMapped(classicDelegates, (match) {
        final headEntries = (match.group(2) ?? '').trimRight();
        return 'static List<LocalizationsDelegate<dynamic>> '
            'get localizationsDelegates => [\n'
            '$headEntries\n'
            '    ...GlobalMaterialLocalizations.delegates,\n'
            '  ];';
      });
    } else {
      // Fallback: swap individual deprecated delegates if the block shape differs.
      source = source.replaceAll(
        'GlobalMaterialLocalizations.delegate',
        '...GlobalMaterialLocalizations.delegates /* material_ui */',
      );
      // If we expanded Material to a spread, drop redundant Cupertino/Widgets
      // lines that material_ui's combined list already includes.
      source = source.replaceAll(
        RegExp(
          r'^\s*GlobalCupertinoLocalizations\.delegate,\s*$',
          multiLine: true,
        ),
        '',
      );
      source = source.replaceAll(
        RegExp(
          r'^\s*GlobalWidgetsLocalizations\.delegate,\s*$',
          multiLine: true,
        ),
        '',
      );
    }

    if (source == original) return false;
    await file.writeAsString(source);
    return true;
  }
}
