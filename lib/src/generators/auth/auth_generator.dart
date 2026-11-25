import 'dart:io';

import 'package:path/path.dart' as p;

import '../../config/models.dart';
import '../../core/exceptions.dart';
import '../../fs/custom_regions.dart';
import '../../fs/write_plan.dart';
import '../context.dart';
import '../result.dart';
import '../runner.dart';
import '../shared/ui_imports.dart';

/// Generates a session/auth scaffold that plugs into generated API auth.
///
/// Usage:
///   `devkit generate auth session`
///   `devkit generate auth session --ui`  (login page + route guard)
final class AuthGenerator extends BaseGenerator {
  @override
  String get name => 'auth';

  @override
  String get description =>
      'Generate a session token holder and API auth hook (stub credentials).';

  @override
  Future<void> validate(GenerationContext context) async {
    final kind = context.targetName.snakeCase;
    if (kind != 'session') {
      throw InvalidUsageException(
        'Unknown auth pack "$kind".',
        details: 'Supported: session\nExample: devkit generate auth session',
      );
    }
    if (context.extra['ui'] == true) {
      if (context.config.flutter.routing != Routing.goRouter) {
        throw const InvalidUsageException(
          'Auth --ui requires go_router routing.',
          details:
              'Navigator 1.0 has no DevKit route guard yet.\n'
              'Create/adopt with --routing go_router, or generate auth '
              'session without --ui.',
        );
      }
      if (context.config.flutter.dependencyInjection !=
          DependencyInjection.getIt) {
        throw const InvalidUsageException(
          'Auth --ui requires get_it dependency injection.',
          details:
              'The login guard needs SessionAuth from get_it.\n'
              'Create/adopt with --di get_it, or generate auth session '
              'without --ui and wire SessionAuth yourself.',
        );
      }
      final router = File(
        p.join(
          context.projectRoot,
          'lib',
          'core',
          'routing',
          'app_router.dart',
        ),
      );
      if (!router.existsSync()) {
        throw const InvalidUsageException(
          'Auth --ui requires lib/core/routing/app_router.dart.',
          details:
              'Create the app with DevKit, or run `devkit adopt`, then re-run.',
        );
      }
      final source = router.readAsStringSync();
      if (!source.contains('AppRouter') || !source.contains('featureRoutes')) {
        throw const InvalidUsageException(
          'Auth --ui requires DevKit AppRouter anchors (featureRoutes).',
          details:
              'Expected abstract AppRouter with featureRoutes in '
              'lib/core/routing/app_router.dart.',
        );
      }
      final injector = File(
        p.join(context.projectRoot, 'lib', 'core', 'di', 'injector.dart'),
      );
      if (!injector.existsSync()) {
        throw const InvalidUsageException(
          'Auth --ui requires lib/core/di/injector.dart for get_it.',
        );
      }
      if (!injector.readAsStringSync().contains('registerFeatures(getIt);')) {
        throw const InvalidUsageException(
          'Auth --ui could not find registerFeatures(getIt); in injector.dart.',
        );
      }
    }
  }

  @override
  Future<GenerationResult> generate(GenerationContext context) async {
    final project = context.config.project.name;
    final di = context.config.flutter.dependencyInjection;
    final withUi = context.extra['ui'] == true;
    final useMaterialUi = await UiImports.projectUsesMaterialUi(
      context.projectRoot,
    );

    final writes = <PlannedFileWrite>[
      PlannedFileWrite(
        relativePath: 'lib/core/auth/session_token_store.dart',
        content: _tokenStore(),
      ),
      PlannedFileWrite(
        relativePath: 'lib/core/auth/session_auth.dart',
        content: _sessionAuth(project: project),
      ),
      PlannedFileWrite(
        relativePath: 'lib/core/config/app_config.dart',
        content: _appConfig(),
      ),
    ];

    if (di == DependencyInjection.getIt) {
      writes.add(
        PlannedFileWrite(
          relativePath: 'lib/core/di/auth_registrations.dart',
          content: _getItRegistrations(project: project),
        ),
      );
      final injector = _upsertInjectorRegisterAuth(context.projectRoot);
      if (injector != null) {
        writes.add(
          PlannedFileWrite(
            relativePath: 'lib/core/di/injector.dart',
            content: injector,
            mode: FileWriteMode.overwrite,
          ),
        );
      }
    }

    if (withUi) {
      final routing = context.config.flutter.routing;
      writes.add(
        PlannedFileWrite(
          relativePath: 'lib/features/auth/presentation/pages/login_page.dart',
          content: _loginPage(
            project: project,
            useMaterialUi: useMaterialUi,
            di: di,
            routing: routing,
          ),
        ),
      );
      writes.add(
        PlannedFileWrite(
          relativePath: 'lib/core/routing/app_router.dart',
          content: _upsertAppRouterGuard(
            root: context.projectRoot,
            project: project,
            routing: routing,
            di: di,
          ),
          mode: FileWriteMode.overwrite,
        ),
      );
    }

    return commitWrites(
      context: context,
      writes: writes,
      message: withUi
          ? 'Auth session + login UI generated.\n'
                'Visit /login; /features/* redirects when unsigned-in.\n'
                'Stub sign-in accepts any non-empty password.'
          : 'Auth session scaffold generated.\n'
                'Wire SessionAuth into your API client auth (bearer token).\n'
                'Select flavor with --dart-define=ENV=dev|staging|prod.\n'
                'Add --ui for login page + route guard.',
    );
  }

  String? _upsertInjectorRegisterAuth(String root) {
    final file = File(p.join(root, 'lib', 'core', 'di', 'injector.dart'));
    if (!file.existsSync()) return null;
    var source = file.readAsStringSync();
    if (!source.contains('registerAuth')) {
      if (!source.contains('auth_registrations.dart')) {
        source = source.replaceFirst(
          "import 'feature_registrations.dart';",
          "import 'auth_registrations.dart';\nimport 'feature_registrations.dart';",
        );
        if (!source.contains('auth_registrations.dart')) {
          source = "import 'auth_registrations.dart';\n$source";
        }
      }
      if (source.contains('registerFeatures(getIt);')) {
        source = source.replaceFirst(
          'registerFeatures(getIt);',
          'registerAuth(getIt);\n  registerFeatures(getIt);',
        );
      } else {
        throw const InvalidUsageException(
          'Could not hook registerAuth into injector.dart.',
          details: 'Expected registerFeatures(getIt); call site.',
        );
      }
    }
    return source;
  }

  String _upsertAppRouterGuard({
    required String root,
    required String project,
    required Routing routing,
    required DependencyInjection di,
  }) {
    // Validated in validate(): go_router + get_it only.
    // File is overwritten; commitWrites merges custom regions from disk.
    if (routing != Routing.goRouter || di != DependencyInjection.getIt) {
      throw const InvalidUsageException(
        'Auth --ui requires go_router and get_it.',
      );
    }
    return '''
import 'package:go_router/go_router.dart';
import 'package:$project/core/di/injector.dart';
import 'package:$project/core/auth/session_auth.dart';
import 'package:$project/features/auth/presentation/pages/login_page.dart';
import 'package:$project/features/home/presentation/pages/home_page.dart';
import 'feature_routes.dart';

/// Application router (go_router) with auth redirect for /features/*.
abstract final class AppRouter {
  static final GoRouter router = GoRouter(
    redirect: (context, state) {
      final path = state.uri.path;
      final signedIn = getIt.isRegistered<SessionAuth>() &&
          getIt<SessionAuth>().bearerToken != null;
      final loggingIn = path == '/login';
      if (!signedIn && path.startsWith('/features')) {
        return '/login';
      }
      if (signedIn && loggingIn) {
        return '/';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const HomePage(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginPage(),
      ),
      ...featureRoutes,
    ],
  );
}

${CustomRegions.stub('router.extra', comment: 'Extra GoRouter options')}
''';
  }

  String _loginPage({
    required String project,
    required bool useMaterialUi,
    required DependencyInjection di,
    required Routing routing,
  }) {
    final materialImport = UiImports.materialImport(useMaterialUi: useMaterialUi);
    final authResolve = switch (di) {
      DependencyInjection.getIt => 'getIt<SessionAuth>()',
      DependencyInjection.manual => 'SessionAuth(SessionTokenStore())',
      DependencyInjection.riverpod => 'SessionAuth(SessionTokenStore())',
    };
    final diImport = di == DependencyInjection.getIt
        ? "import 'package:$project/core/di/injector.dart';"
        : '';
    final storeImport = di == DependencyInjection.getIt
        ? ''
        : "import 'package:$project/core/auth/session_token_store.dart';\n";
    final goRouterImport = routing == Routing.goRouter
        ? "import 'package:go_router/go_router.dart';\n"
        : '';
    final navigateHome = routing == Routing.goRouter
        ? "    context.go('/');"
        : "    Navigator.of(context).pushReplacementNamed('/');";
    return '''
$materialImport
$goRouterImport
import 'package:$project/core/auth/session_auth.dart';
$storeImport$diImport

/// Generated by Chico Flutter DevKit — stub login (any non-empty password).
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final password = _password.text.trim();
    if (password.isEmpty) {
      setState(() => _error = 'Password required');
      return;
    }
    final auth = $authResolve;
    await auth.signInStub(token: 'stub-\${_email.text.trim()}');
${CustomRegions.stub('login.afterSignIn', comment: 'Post sign-in hooks')}
    if (!mounted) return;
$navigateHome
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(
              controller: _email,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
            ),
            if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            FilledButton(onPressed: _submit, child: const Text('Sign in')),
          ],
        ),
      ),
    );
  }
}
''';
  }

  String _tokenStore() => '''
/// Generated by Chico Flutter DevKit — in-memory token holder.
///
/// Swap the implementation for flutter_secure_storage (or similar) when ready.
class SessionTokenStore {
  String? _accessToken;

  String? get accessToken => _accessToken;

  void save(String token) => _accessToken = token;

  void clear() => _accessToken = null;
}
''';

  String _sessionAuth({required String project}) =>
      '''
import 'package:$project/core/auth/session_token_store.dart';
import 'package:$project/core/config/app_config.dart';

/// Generated by Chico Flutter DevKit — session façade for API clients.
class SessionAuth {
  SessionAuth(this._store);

  final SessionTokenStore _store;

  String? get bearerToken => _store.accessToken;

  bool get isSignedIn => _accessTokenOrNull != null;

  String? get _accessTokenOrNull => _store.accessToken;

  AppConfig get config => AppConfig.current;

  Future<void> signInStub({required String token}) async {
    _store.save(token);
  }

  Future<void> signOut() async {
    _store.clear();
  }
}
''';

  String _appConfig() => '''
/// Generated by Chico Flutter DevKit — flavor config via --dart-define=ENV=…
class AppConfig {
  const AppConfig({
    required this.env,
    required this.apiBaseUrl,
  });

  final String env;
  final String apiBaseUrl;

  static const dev = AppConfig(
    env: 'dev',
    apiBaseUrl: 'https://api-dev.example.com/v1',
  );

  static const staging = AppConfig(
    env: 'staging',
    apiBaseUrl: 'https://api-staging.example.com/v1',
  );

  static const prod = AppConfig(
    env: 'prod',
    apiBaseUrl: 'https://api.example.com/v1',
  );

  static AppConfig get current {
    const env = String.fromEnvironment('ENV', defaultValue: 'dev');
    return switch (env) {
      'staging' => staging,
      'prod' => prod,
      _ => dev,
    };
  }
}
''';

  String _getItRegistrations({required String project}) =>
      '''
import 'package:get_it/get_it.dart';

import 'package:$project/core/auth/session_auth.dart';
import 'package:$project/core/auth/session_token_store.dart';

/// Call from your DI bootstrap after core modules.
void registerAuth(GetIt getIt) {
  if (!getIt.isRegistered<SessionTokenStore>()) {
    getIt.registerLazySingleton<SessionTokenStore>(SessionTokenStore.new);
  }
  if (!getIt.isRegistered<SessionAuth>()) {
    getIt.registerLazySingleton<SessionAuth>(
      () => SessionAuth(getIt()),
    );
  }
}
''';
}
