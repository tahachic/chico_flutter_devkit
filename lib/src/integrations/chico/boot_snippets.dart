import '../../config/models.dart';
import 'chico_packages.dart';

/// Verified Chico boot snippets — do not invent APIs beyond these.
abstract final class ChicoBootSnippets {
  /// Import line for the highest enabled Chico layer.
  static String importLine(ChicoIntegrationsConfig chico) {
    if (chico.services.enabled) {
      return "import 'package:chico_services/chico_services.dart';";
    }
    if (chico.kit.enabled) {
      return "import 'package:chico_kit/chico_kit.dart';";
    }
    if (chico.ui.enabled) {
      return "import 'package:chico_ui/chico_ui.dart';";
    }
    return "import 'package:flutter/material.dart';";
  }

  /// `main()` body prelude (async init when services enabled).
  static String mainPrelude({
    required ChicoIntegrationsConfig chico,
    String apiBaseUrl = 'https://api.example.com',
  }) {
    if (chico.services.enabled) {
      return '''
  WidgetsFlutterBinding.ensureInitialized();
  await ChicoServices.init(baseUrl: '$apiBaseUrl');
''';
    }
    return '';
  }

  static bool mainIsAsync(ChicoIntegrationsConfig chico) =>
      chico.services.enabled;

  /// Root widget constructor using verified ChicoApp APIs when enabled.
  static String rootApp({
    required ChicoIntegrationsConfig chico,
    required Routing routing,
    required String homeWidget,
    required String routerGetter,
  }) {
    final useChico =
        chico.ui.enabled || chico.kit.enabled || chico.services.enabled;
    if (!useChico) {
      if (routing == Routing.goRouter) {
        return 'MaterialApp.router(routerConfig: $routerGetter)';
      }
      return 'MaterialApp(home: $homeWidget)';
    }

    if (routing == Routing.goRouter) {
      return '''ChicoApp.router(
      theme: ChicoThemeData.light(tint: const Color(0xFF007AFF)),
      darkTheme: ChicoThemeData.dark(tint: const Color(0xFF0A84FF)),
      routerConfig: $routerGetter,
    )''';
    }

    return '''ChicoApp(
      theme: ChicoThemeData.light(tint: const Color(0xFF007AFF)),
      darkTheme: ChicoThemeData.dark(tint: const Color(0xFF0A84FF)),
      home: $homeWidget,
    )''';
  }

  static String documentationFor(ChicoPackageId id) {
    return switch (id) {
      ChicoPackageId.ui =>
        'chico_ui: wrap the app with ChicoApp / ChicoApp.router. '
            'Import package:chico_ui/chico_ui.dart',
      ChicoPackageId.kit =>
        'chico_kit: helpers that re-export chico_ui. '
            'Import package:chico_kit/chico_kit.dart (no init call).',
      ChicoPackageId.services =>
        'chico_services: call '
            "await ChicoServices.init(baseUrl: '...'); before runApp. "
            'Import package:chico_services/chico_services.dart',
    };
  }
}
