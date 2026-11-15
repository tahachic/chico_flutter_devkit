import '../../config/models.dart';
import '../../fs/write_plan.dart';
import '../../integrations/chico/boot_snippets.dart';
import '../project_options.dart';

/// Builds starter overlay files for a newly created Flutter app.
abstract final class AppScaffold {
  static List<PlannedFileWrite> build(ProjectCreateOptions options) {
    final name = options.normalizedName;
    final writes = <PlannedFileWrite>[
      PlannedFileWrite(
        relativePath: 'lib/main.dart',
        content: _main(options),
        mode: FileWriteMode.overwrite,
      ),
      PlannedFileWrite(
        relativePath: 'lib/app.dart',
        content: _app(options),
        mode: FileWriteMode.overwrite,
      ),
      PlannedFileWrite(
        relativePath: 'lib/core/theme/app_theme.dart',
        content: _theme(options),
        mode: FileWriteMode.overwrite,
      ),
      PlannedFileWrite(
        relativePath: 'lib/core/routing/app_router.dart',
        content: _router(options),
        mode: FileWriteMode.overwrite,
      ),
      if (options.routing == Routing.goRouter)
        PlannedFileWrite(
          relativePath: 'lib/core/routing/feature_routes.dart',
          content: _featureRoutes(),
          mode: FileWriteMode.overwrite,
        ),
      PlannedFileWrite(
        relativePath: 'lib/core/di/injector.dart',
        content: _di(options),
        mode: FileWriteMode.overwrite,
      ),
      if (options.dependencyInjection == DependencyInjection.getIt)
        PlannedFileWrite(
          relativePath: 'lib/core/di/feature_registrations.dart',
          content: _featureRegistrations(),
          mode: FileWriteMode.overwrite,
        ),
      PlannedFileWrite(
        relativePath: 'lib/features/home/presentation/pages/home_page.dart',
        content: _homePage(options),
        mode: FileWriteMode.overwrite,
      ),
      PlannedFileWrite(
        relativePath: 'README.md',
        content: _readme(options),
        mode: FileWriteMode.overwrite,
      ),
      PlannedFileWrite(
        relativePath: 'test/widget_test.dart',
        content: _widgetTest(options),
        mode: FileWriteMode.overwrite,
      ),
    ];

    if (options.enableErrorHandling) {
      writes.add(
        PlannedFileWrite(
          relativePath: 'lib/core/errors/app_error.dart',
          content: _errors(),
          mode: FileWriteMode.overwrite,
        ),
      );
    }

    if (options.enableLogging) {
      writes.add(
        PlannedFileWrite(
          relativePath: 'lib/core/logging/app_logger.dart',
          content: _logger(),
          mode: FileWriteMode.overwrite,
        ),
      );
    }

    if (options.enableLocalization) {
      writes.add(
        PlannedFileWrite(
          relativePath: 'lib/core/l10n/app_localizations.dart',
          content: _l10n(options),
          mode: FileWriteMode.overwrite,
        ),
      );
    }

    // Architecture placeholder folders via .gitkeep-style docs.
    writes.addAll(_architecturePlaceholders(options));

    // Silence unused in some templates.
    assert(name.snakeCase.isNotEmpty);
    return writes;
  }

  static String _main(ProjectCreateOptions options) {
    final prelude = ChicoBootSnippets.mainPrelude(
      chico: options.chicoConfig,
      apiBaseUrl: options.apiBaseUrl,
    );
    final chicoImport =
        options.enableChicoUi ||
            options.enableChicoKit ||
            options.enableChicoServices
        ? '${ChicoBootSnippets.importLine(options.chicoConfig)}\n'
        : '';

    return '''
import 'package:flutter/widgets.dart';
$chicoImport
import 'app.dart';
import 'core/di/injector.dart';

Future<void> main() async {
$prelude
  await configureDependencies();
  runApp(const ${options.normalizedName.pascalCase}App());
}
''';
  }

  static String _app(ProjectCreateOptions options) {
    final pascal = options.normalizedName.pascalCase;
    final useChico =
        options.enableChicoUi ||
        options.enableChicoKit ||
        options.enableChicoServices;
    final useRiverpod =
        options.stateManagement == StateManagement.riverpod ||
        options.dependencyInjection == DependencyInjection.riverpod;
    // Chico roots use ChicoApp + Color from flutter/widgets — do not import
    // package:flutter/material.dart (deprecated after Flutter 3.47; fails
    // `flutter analyze --fatal-infos` on current stable).
    final imports = StringBuffer();
    if (useChico) {
      imports.writeln("import 'package:flutter/widgets.dart';");
      imports.writeln(ChicoBootSnippets.importLine(options.chicoConfig));
    } else {
      imports.writeln("import 'package:flutter/material.dart';");
    }
    if (useRiverpod) {
      imports.writeln(
        "import 'package:flutter_riverpod/flutter_riverpod.dart';",
      );
    }
    if (options.routing == Routing.goRouter) {
      imports.writeln("import 'core/routing/app_router.dart';");
    } else {
      imports.writeln(
        "import 'features/home/presentation/pages/home_page.dart';",
      );
    }

    final root = ChicoBootSnippets.rootApp(
      chico: options.chicoConfig,
      routing: options.routing,
      homeWidget: 'const HomePage()',
      routerGetter: 'AppRouter.router',
    );
    final wrapped = useRiverpod ? 'ProviderScope(child: $root)' : root;

    return '''
$imports
/// Root application widget.
class ${pascal}App extends StatelessWidget {
  const ${pascal}App({super.key});

  @override
  Widget build(BuildContext context) {
    return $wrapped;
  }
}
''';
  }

  static String _theme(ProjectCreateOptions options) {
    if (options.enableChicoUi ||
        options.enableChicoKit ||
        options.enableChicoServices) {
      return '''
${ChicoBootSnippets.importLine(options.chicoConfig)}
import 'package:flutter/widgets.dart';

/// Chico theme helpers.
abstract final class AppTheme {
  static ChicoThemeData get light =>
      ChicoThemeData.light(tint: const Color(0xFF007AFF));

  static ChicoThemeData get dark =>
      ChicoThemeData.dark(tint: const Color(0xFF0A84FF));
}
''';
    }

    return '''
import 'package:flutter/material.dart';

/// Material theme helpers.
abstract final class AppTheme {
  static ThemeData get light => ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF007AFF)),
        useMaterial3: true,
      );

  static ThemeData get dark => ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0A84FF),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      );
}
''';
  }

  static String _router(ProjectCreateOptions options) {
    if (options.routing == Routing.goRouter) {
      return '''
import 'package:go_router/go_router.dart';

import '../../features/home/presentation/pages/home_page.dart';
import 'feature_routes.dart';

/// Application router.
abstract final class AppRouter {
  static final GoRouter router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const HomePage(),
      ),
      ...featureRoutes,
    ],
  );
}
''';
    }

    // Navigator is rejected by `devkit create` in this release.
    return '''
/// Unsupported navigator router stub (go_router is the supported option).
abstract final class AppRouter {
  static const home = '/';
}
''';
  }

  static String _featureRoutes() => '''
import 'package:go_router/go_router.dart';

// <devkit:feature-route-imports>
// </devkit:feature-route-imports>

/// GoRoutes appended by `devkit generate feature`.
List<RouteBase> get featureRoutes => [
  // <devkit:feature-routes>
  // </devkit:feature-routes>
];
''';

  static String _featureRegistrations() => '''
import 'package:get_it/get_it.dart';

// <devkit:feature-di-imports>
// </devkit:feature-di-imports>

/// Feature DI registrations appended by `devkit generate feature`.
void registerFeatures(GetIt getIt) {
  // <devkit:feature-registrations>
  // </devkit:feature-registrations>
}
''';

  static String _di(ProjectCreateOptions options) {
    return switch (options.dependencyInjection) {
      DependencyInjection.getIt =>
        '''
import 'package:get_it/get_it.dart';

import 'feature_registrations.dart';

final GetIt getIt = GetIt.instance;

/// Registers app-wide dependencies (get_it scaffold).
Future<void> configureDependencies() async {
  registerFeatures(getIt);
}
''',
      DependencyInjection.riverpod =>
        '''
/// Riverpod composition root.
///
/// Feature providers live beside features; [ProviderScope] wraps the app.
Future<void> configureDependencies() async {}
''',
      DependencyInjection.manual =>
        '''
/// Manual DI composition-root stub.
Future<void> configureDependencies() async {}
''',
    };
  }

  static String _homePage(ProjectCreateOptions options) {
    final useChico =
        options.enableChicoUi ||
        options.enableChicoKit ||
        options.enableChicoServices;
    final title = options.normalizedName.pascalCase;
    if (useChico) {
      return '''
${ChicoBootSnippets.importLine(options.chicoConfig)}
import 'package:flutter/widgets.dart';

/// Example home screen.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChicoScaffold(
      bar: const ChicoBar(title: '$title'),
      body: ChicoPage(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ChicoText(
              'Welcome to $title',
              variant: ChicoTextVariant.title,
            ),
            // <devkit:home-features>
            // </devkit:home-features>
          ],
        ),
      ),
    );
  }
}
''';
    }

    return '''
import 'package:flutter/material.dart';

/// Example home screen.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('$title')),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Welcome to $title'),
          ),
          // <devkit:home-features>
          // </devkit:home-features>
        ],
      ),
    );
  }
}
''';
  }

  static String _errors() => '''
/// Application error type.
sealed class AppError implements Exception {
  const AppError(this.message);
  final String message;

  @override
  String toString() => message;
}

final class UnexpectedAppError extends AppError {
  const UnexpectedAppError(super.message);
}
''';

  static String _logger() => '''
/// Lightweight app logger.
abstract final class AppLogger {
  static void info(String message) => _log('INFO', message);
  static void warn(String message) => _log('WARN', message);
  static void error(String message) => _log('ERROR', message);

  static void _log(String level, String message) {
    // ignore: avoid_print
    print('[\$level] \$message');
  }
}
''';

  static String _l10n(ProjectCreateOptions options) {
    final languages = options.enableLocalization ? "['en']" : "['en']";
    return '''
/// Lightweight localization scaffold (not flutter gen-l10n).
///
/// Replace with generated localizations when you adopt ARB files.
abstract final class AppLocalizations {
  static const supported = $languages;

  static String greet(String locale) => switch (locale) {
        'fr' => 'Bonjour',
        'ar' => 'مرحبا',
        _ => 'Hello',
      };
}
''';
  }

  static List<PlannedFileWrite> _architecturePlaceholders(
    ProjectCreateOptions options,
  ) {
    final paths = switch (options.architecture) {
      Architecture.clean || Architecture.featureFirst => [
        'lib/features/.gitkeep',
        'lib/core/.gitkeep',
      ],
      Architecture.layered => [
        'lib/data/.gitkeep',
        'lib/domain/.gitkeep',
        'lib/presentation/.gitkeep',
        'lib/core/.gitkeep',
      ],
    };
    return paths
        .map(
          (path) => PlannedFileWrite(
            relativePath: path,
            content: '',
            mode: FileWriteMode.skipIfExists,
          ),
        )
        .toList();
  }

  static String _readme(ProjectCreateOptions options) {
    return '''
# ${options.normalizedName.pascalCase}

Generated by **Chico Flutter DevKit**.

## Stack

- Architecture: `${options.architecture.yamlValue}`
- State: `${options.stateManagement.yamlValue}`
- Routing: `${options.routing.yamlValue}`
- DI: `${options.dependencyInjection.yamlValue}`
- Chico UI: `${options.enableChicoUi}`
- Chico Kit: `${options.enableChicoKit}`
- Chico Services: `${options.enableChicoServices}`

## Run

```bash
flutter pub get
flutter run
```

## DevKit

```bash
devkit generate feature products
devkit doctor
```
''';
  }

  static String _widgetTest(ProjectCreateOptions options) {
    final pascal = options.normalizedName.pascalCase;
    return '''
import 'package:flutter_test/flutter_test.dart';
import 'package:${options.normalizedName.snakeCase}/app.dart';

void main() {
  testWidgets('$pascal smoke test', (tester) async {
    await tester.pumpWidget(const ${pascal}App());
    expect(find.textContaining('Welcome'), findsOneWidget);
  });
}
''';
  }
}
