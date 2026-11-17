import '../../config/models.dart';
import '../../fs/write_plan.dart';
import '../../generators/shared/ui_imports.dart';
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
      PlannedFileWrite(
        relativePath: 'lib/core/routing/feature_routes.dart',
        content: _featureRoutes(options),
        mode: FileWriteMode.overwrite,
      ),
      PlannedFileWrite(
        relativePath: 'lib/core/di/app_config.dart',
        content: _appConfig(options),
        mode: FileWriteMode.overwrite,
      ),
      ..._diFiles(options),
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
      writes.addAll(_genL10nFiles(options));
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
    final riverpodDi =
        options.dependencyInjection == DependencyInjection.riverpod;
    final useRiverpod =
        options.stateManagement == StateManagement.riverpod || riverpodDi;
    // Chico roots use ChicoApp + Color from flutter/widgets.
    // Material-first apps prefer package:material_ui on Flutter ≥ 3.47.
    final imports = StringBuffer();
    if (useChico) {
      imports.writeln("import 'package:flutter/widgets.dart';");
      imports.writeln(ChicoBootSnippets.importLine(options.chicoConfig));
    } else {
      imports.writeln(
        UiImports.materialImport(useMaterialUi: options.useMaterialUi),
      );
      imports.writeln("import 'core/theme/app_theme.dart';");
    }
    if (useRiverpod) {
      imports.writeln(
        "import 'package:flutter_riverpod/flutter_riverpod.dart';",
      );
    }
    if (riverpodDi) {
      imports.writeln("import 'core/di/injector.dart';");
    }
    if (options.enableLocalization) {
      imports.writeln(
        "import 'package:${options.normalizedName.snakeCase}/l10n/app_localizations.dart';",
      );
    }
    imports.writeln("import 'core/routing/app_router.dart';");

    final root = ChicoBootSnippets.rootApp(
      chico: options.chicoConfig,
      routing: options.routing,
      homeWidget: 'const HomePage()',
      routerGetter: 'AppRouter.router',
      enableLocalization: options.enableLocalization,
    );
    final String wrapped;
    if (riverpodDi) {
      wrapped =
          'UncontrolledProviderScope(container: appContainer, child: $root)';
    } else if (useRiverpod) {
      wrapped = 'ProviderScope(child: $root)';
    } else {
      wrapped = root;
    }

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
${UiImports.materialImport(useMaterialUi: options.useMaterialUi)}

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

/// Application router (go_router).
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

    return '''
import 'package:flutter/widgets.dart';

import '../../features/home/presentation/pages/home_page.dart';
import 'feature_routes.dart';

/// Application router (Navigator 1.0 named routes).
abstract final class AppRouter {
  static const home = '/';

  static Map<String, WidgetBuilder> get routes => {
        home: (_) => const HomePage(),
        ...featureRoutes,
      };
}
''';
  }

  static String _featureRoutes(ProjectCreateOptions options) {
    if (options.routing == Routing.goRouter) {
      return '''
import 'package:go_router/go_router.dart';

// <devkit:feature-route-imports>
// </devkit:feature-route-imports>

/// GoRoutes appended by `devkit generate feature`.
List<RouteBase> get featureRoutes => [
  // <devkit:feature-routes>
  // </devkit:feature-routes>
];
''';
    }

    return '''
import 'package:flutter/widgets.dart';

// <devkit:feature-route-imports>
// </devkit:feature-route-imports>

/// Named routes appended by `devkit generate feature`.
Map<String, WidgetBuilder> get featureRoutes => {
  // <devkit:feature-routes>
  // </devkit:feature-routes>
};
''';
  }

  static String _appConfig(ProjectCreateOptions options) {
    final name = options.normalizedName.pascalCase;
    return '''
/// App-wide configuration (injected by the composition root).
final class AppConfig {
  const AppConfig({
    this.appName = '$name',
    this.apiBaseUrl = 'https://api.example.com',
  });

  final String appName;
  final String apiBaseUrl;
}
''';
  }

  static List<PlannedFileWrite> _diFiles(ProjectCreateOptions options) {
    return switch (options.dependencyInjection) {
      DependencyInjection.getIt => [
        PlannedFileWrite(
          relativePath: 'lib/core/di/core_module.dart',
          content: _getItCoreModule(options),
          mode: FileWriteMode.overwrite,
        ),
        PlannedFileWrite(
          relativePath: 'lib/core/di/feature_registrations.dart',
          content: _featureRegistrations(),
          mode: FileWriteMode.overwrite,
        ),
        PlannedFileWrite(
          relativePath: 'lib/core/di/injector.dart',
          content: _getItInjector(options),
          mode: FileWriteMode.overwrite,
        ),
      ],
      DependencyInjection.riverpod => [
        PlannedFileWrite(
          relativePath: 'lib/core/di/app_providers.dart',
          content: _riverpodAppProviders(options),
          mode: FileWriteMode.overwrite,
        ),
        PlannedFileWrite(
          relativePath: 'lib/core/di/feature_providers.dart',
          content: _riverpodFeatureProviders(),
          mode: FileWriteMode.overwrite,
        ),
        PlannedFileWrite(
          relativePath: 'lib/core/di/injector.dart',
          content: _riverpodInjector(options),
          mode: FileWriteMode.overwrite,
        ),
      ],
      DependencyInjection.manual => [
        PlannedFileWrite(
          relativePath: 'lib/core/di/app_services.dart',
          content: _manualAppServices(options),
          mode: FileWriteMode.overwrite,
        ),
        PlannedFileWrite(
          relativePath: 'lib/core/di/feature_factories.dart',
          content: _manualFeatureFactories(),
          mode: FileWriteMode.overwrite,
        ),
        PlannedFileWrite(
          relativePath: 'lib/core/di/injector.dart',
          content: _manualInjector(options),
          mode: FileWriteMode.overwrite,
        ),
      ],
    };
  }

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

  static String _getItCoreModule(ProjectCreateOptions options) {
    final imports = StringBuffer()
      ..writeln("import 'package:get_it/get_it.dart';")
      ..writeln("import 'app_config.dart';");
    final body = StringBuffer()
      ..writeln('''
  if (!getIt.isRegistered<AppConfig>()) {
    getIt.registerLazySingleton<AppConfig>(() => const AppConfig());
  }''');
    if (options.enableLogging) {
      imports.writeln("import '../logging/app_logger.dart';");
      body.writeln('''
  if (!getIt.isRegistered<AppLogger>()) {
    getIt.registerLazySingleton<AppLogger>(AppLogger.new);
  }''');
    }
    return '''
$imports
/// App-wide get_it registrations (config, logging, …).
void registerCore(GetIt getIt) {
${body.toString().trimRight()}
}
''';
  }

  static String _getItInjector(ProjectCreateOptions options) {
    final logLine = options.enableLogging
        ? "  getIt<AppLogger>().info('get_it dependencies configured');"
        : '';
    final loggerImport = options.enableLogging
        ? "import '../logging/app_logger.dart';\n"
        : '';
    return '''
import 'package:get_it/get_it.dart';

import 'app_config.dart';
import 'core_module.dart';
import 'feature_registrations.dart';
$loggerImport
final GetIt getIt = GetIt.instance;

/// get_it composition root — core module then feature modules.
Future<void> configureDependencies() async {
  registerCore(getIt);
  registerFeatures(getIt);
$logLine
}

/// Convenience: resolve [AppConfig] from the locator.
AppConfig get appConfig => getIt<AppConfig>();
''';
  }

  static String _riverpodAppProviders(ProjectCreateOptions options) {
    final loggerProvider = options.enableLogging
        ? '''
final appLoggerProvider = Provider<AppLogger>((ref) => const AppLogger());
'''
        : '';
    final loggerImport = options.enableLogging
        ? "import '../logging/app_logger.dart';\n"
        : '';
    return '''
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_config.dart';
$loggerImport
/// App-wide Riverpod providers.
final appConfigProvider = Provider<AppConfig>((ref) => const AppConfig());

final appNameProvider = Provider<String>(
  (ref) => ref.watch(appConfigProvider).appName,
);
$loggerProvider''';
  }

  static String _riverpodFeatureProviders() => '''
// <devkit:feature-provider-exports>
// </devkit:feature-provider-exports>

/// Barrel of feature providers — appended by `devkit generate feature`.
///
/// Prefer importing feature providers beside the feature; this file is for
/// discoverability and shared overrides in tests.
''';

  static String _riverpodInjector(ProjectCreateOptions options) {
    final logLine = options.enableLogging
        ? "  appContainer.read(appLoggerProvider).info('Riverpod container ready');"
        : '';
    return '''
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_providers.dart';

export 'app_providers.dart';
export 'feature_providers.dart';

/// Shared [ProviderContainer] used by [UncontrolledProviderScope] in app.dart.
///
/// Tests can create a fresh container with overrides instead of mutating this.
final ProviderContainer appContainer = ProviderContainer();

/// Riverpod composition root — providers resolve lazily; bootstrap reads here.
Future<void> configureDependencies() async {
  // Touch app-wide providers so misconfiguration fails at startup.
  appContainer.read(appConfigProvider);
$logLine
}
''';
  }

  static String _manualAppServices(ProjectCreateOptions options) {
    final loggerField = options.enableLogging
        ? '  final AppLogger logger;\n'
        : '';
    final loggerParam = options.enableLogging
        ? 'required this.logger,\n    '
        : '';
    final loggerImport = options.enableLogging
        ? "import '../logging/app_logger.dart';\n"
        : '';
    return '''
import 'app_config.dart';
$loggerImport
/// Hand-wired app services (manual DI — no service locator package).
final class AppServices {
  AppServices({
    required this.config,
    $loggerParam});

  final AppConfig config;
$loggerField}

/// Process-wide holder set by [configureDependencies].
abstract final class ServiceLocator {
  static late AppServices services;
}
''';
  }

  static String _manualFeatureFactories() => '''
// <devkit:feature-factory-imports>
// </devkit:feature-factory-imports>

/// Feature factories appended by `devkit generate feature`.
///
/// Pages call these instead of constructing the graph inline.
abstract final class FeatureFactories {
  // <devkit:feature-factories>
  // </devkit:feature-factories>
}
''';

  static String _manualInjector(ProjectCreateOptions options) {
    final loggerArg = options.enableLogging
        ? 'logger: const AppLogger(),\n    '
        : '';
    final logLine = options.enableLogging
        ? "  ServiceLocator.services.logger.info('Manual DI ready');"
        : '';
    final loggerImport = options.enableLogging
        ? "import '../logging/app_logger.dart';\n"
        : '';
    return '''
import 'app_config.dart';
import 'app_services.dart';
import 'feature_factories.dart';
$loggerImport
/// Manual composition root — construct the object graph explicitly.
Future<void> configureDependencies() async {
  ServiceLocator.services = AppServices(
    config: const AppConfig(),
    $loggerArg);
$logLine
}
''';
  }

  static String _homePage(ProjectCreateOptions options) {
    final useChico =
        options.enableChicoUi ||
        options.enableChicoKit ||
        options.enableChicoServices;
    final title = options.normalizedName.pascalCase;
    final l10nImport = options.enableLocalization
        ? "import 'package:${options.normalizedName.snakeCase}/l10n/app_localizations.dart';\n"
        : '';
    if (useChico) {
      final titleExpr = options.enableLocalization
          ? 'l10n.appTitle'
          : "'$title'";
      final welcomeExpr = options.enableLocalization
          ? 'l10n.welcomeMessage'
          : "'Welcome to $title'";
      final l10nLine = options.enableLocalization
          ? '    final l10n = AppLocalizations.of(context)!;\n'
          : '';
      return '''
${ChicoBootSnippets.importLine(options.chicoConfig)}
import 'package:flutter/widgets.dart';
$l10nImport
/// Example home screen.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
$l10nLine    return ChicoScaffold(
      bar: ChicoBar(title: $titleExpr),
      body: ChicoPage(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ChicoText(
              $welcomeExpr,
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

    if (options.enableLocalization) {
      return '''
${UiImports.materialImport(useMaterialUi: options.useMaterialUi)}
$l10nImport
/// Example home screen.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.appTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            l10n.welcomeMessage,
            style: textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.generateFeatureHint,
            style: textTheme.bodyMedium,
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

    return '''
${UiImports.materialImport(useMaterialUi: options.useMaterialUi)}

/// Example home screen.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('$title')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Welcome to $title',
            style: textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Generate a feature with: devkit generate feature <name>',
            style: textTheme.bodyMedium,
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

  static List<PlannedFileWrite> _genL10nFiles(ProjectCreateOptions options) {
    final title = options.normalizedName.pascalCase;
    final languages = _normalizedLocales(options.languages);
    final templateLang = languages.contains('en') ? 'en' : languages.first;
    final writes = <PlannedFileWrite>[
      PlannedFileWrite(
        relativePath: 'l10n.yaml',
        content:
            '''
arb-dir: lib/l10n
template-arb-file: app_$templateLang.arb
output-localization-file: app_localizations.dart
output-dir: lib/l10n
''',
        mode: FileWriteMode.overwrite,
      ),
      // Hand-written bootstrap so analyze works before/without gen-l10n;
      // `flutter gen-l10n` overwrites this with the generated implementation.
      PlannedFileWrite(
        relativePath: 'lib/l10n/app_localizations.dart',
        content: _handWrittenLocalizations(options, languages: languages),
        mode: FileWriteMode.overwrite,
      ),
    ];
    for (final lang in languages) {
      writes.add(
        PlannedFileWrite(
          relativePath: 'lib/l10n/app_$lang.arb',
          content: _arbForLocale(lang, appTitle: title),
          mode: FileWriteMode.overwrite,
        ),
      );
    }
    return writes;
  }

  static String _handWrittenLocalizations(
    ProjectCreateOptions options, {
    required List<String> languages,
  }) {
    final title = options.normalizedName.pascalCase;
    final localeList = languages.map((l) => "Locale('$l')").join(', ');
    final cases = StringBuffer();
    for (final lang in languages) {
      final s = _l10nStrings(lang, appTitle: title);
      cases.writeln('''
      case '$lang':
        return (
          appTitle: '${_escapeDart(s.appTitle)}',
          welcomeMessage: '${_escapeDart(s.welcome)}',
          generateFeatureHint: '${_escapeDart(s.hint)}',
        );''');
    }
    final designImports = options.useMaterialUi
        ? "import 'package:material_ui/material_ui.dart';\n"
        : "import 'package:flutter_localizations/flutter_localizations.dart';\n";
    final delegates = options.useMaterialUi
        ? '''
  static List<LocalizationsDelegate<dynamic>> get localizationsDelegates => [
    AppLocalizationsDelegate(),
    ...GlobalMaterialLocalizations.delegates,
  ];'''
        : '''
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = [
    AppLocalizationsDelegate(),
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];''';
    return '''
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
$designImports
/// App localizations (bootstrap). Regenerated by `flutter gen-l10n` from ARB.
final class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  static const List<Locale> supportedLocales = [$localeList];
$delegates

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  late final _strings = _resolve(locale.languageCode);

  String get appTitle => _strings.appTitle;
  String get welcomeMessage => _strings.welcomeMessage;
  String get generateFeatureHint => _strings.generateFeatureHint;

  static ({String appTitle, String welcomeMessage, String generateFeatureHint})
  _resolve(String code) {
    switch (code) {
$cases
      default:
        return (
          appTitle: '${_escapeDart(title)}',
          welcomeMessage: 'Welcome to ${_escapeDart(title)}',
          generateFeatureHint:
              'Generate a feature with: devkit generate feature <name>',
        );
    }
  }
}

final class AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => AppLocalizations.supportedLocales.any(
    (supported) => supported.languageCode == locale.languageCode,
  );

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(AppLocalizations(locale));
  }

  @override
  bool shouldReload(covariant AppLocalizationsDelegate old) => false;
}
''';
  }

  static String _escapeDart(String value) =>
      value.replaceAll(r'\', r'\\').replaceAll("'", r"\'");

  static List<String> _normalizedLocales(List<String> raw) {
    final cleaned = raw
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
    if (cleaned.isEmpty) return const ['en'];
    return cleaned;
  }

  static String _arbForLocale(String lang, {required String appTitle}) {
    final strings = _l10nStrings(lang, appTitle: appTitle);
    return '''
{
  "@@locale": "$lang",
  "appTitle": "${strings.appTitle}",
  "welcomeMessage": "${strings.welcome}",
  "@welcomeMessage": {
    "description": "Home screen welcome line"
  },
  "generateFeatureHint": "${strings.hint}",
  "@generateFeatureHint": {
    "description": "Hint shown under the welcome message"
  }
}
''';
  }

  static ({String appTitle, String welcome, String hint}) _l10nStrings(
    String lang, {
    required String appTitle,
  }) {
    return switch (lang) {
      'fr' => (
        appTitle: appTitle,
        welcome: 'Bienvenue sur $appTitle',
        hint: 'Générez une feature avec : devkit generate feature <name>',
      ),
      'ar' => (
        appTitle: appTitle,
        welcome: 'مرحبًا بك في $appTitle',
        hint: 'أنشئ ميزة باستخدام: devkit generate feature <name>',
      ),
      'es' => (
        appTitle: appTitle,
        welcome: 'Bienvenido a $appTitle',
        hint: 'Genera una feature con: devkit generate feature <name>',
      ),
      'de' => (
        appTitle: appTitle,
        welcome: 'Willkommen bei $appTitle',
        hint: 'Feature erzeugen mit: devkit generate feature <name>',
      ),
      _ => (
        appTitle: appTitle,
        welcome: 'Welcome to $appTitle',
        hint: 'Generate a feature with: devkit generate feature <name>',
      ),
    };
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
/// Lightweight app logger (injectable instance for DI modules).
final class AppLogger {
  const AppLogger();

  void info(String message) => _log('INFO', message);
  void warn(String message) => _log('WARN', message);
  void error(String message) => _log('ERROR', message);

  void _log(String level, String message) {
    // ignore: avoid_print
    print('[\$level] \$message');
  }
}
''';

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
    await tester.pumpAndSettle();
    expect(find.textContaining('Welcome'), findsOneWidget);
  });
}
''';
  }
}
