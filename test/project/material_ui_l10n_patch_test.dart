import 'dart:io';

import 'package:chico_flutter_devkit/src/project/material_ui_l10n_patch.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('devkit_l10n_patch_');
    await Directory(p.join(root.path, 'lib', 'l10n')).create(recursive: true);
  });

  tearDown(() async {
    if (root.existsSync()) await root.delete(recursive: true);
  });

  test(
    'rewrites gen-l10n GlobalMaterial/Cupertino delegates to material_ui',
    () async {
      final file = File(
        p.join(root.path, 'lib', 'l10n', 'app_localizations.dart'),
      );
      await file.writeAsString('''
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = [
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) async => AppLocalizations(locale);

  @override
  bool isSupported(Locale locale) => true;

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
''');

      final changed = await MaterialUiL10nPatch.apply(root.path);
      expect(changed, isTrue);
      final out = await file.readAsString();
      expect(out, contains("import 'package:material_ui/material_ui.dart';"));
      expect(out, contains('...GlobalMaterialLocalizations.delegates'));
      expect(out, isNot(contains('GlobalCupertinoLocalizations.delegate,')));
      expect(out, isNot(contains("import 'package:flutter/widgets.dart';")));
      expect(
        out,
        isNot(
          contains(
            "import 'package:flutter_localizations/flutter_localizations.dart'",
          ),
        ),
      );
    },
  );
}
