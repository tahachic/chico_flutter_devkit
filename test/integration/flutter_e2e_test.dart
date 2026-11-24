@Tags(['flutter_e2e'])
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Real Flutter end-to-end smoke (expensive).
///
/// Run explicitly:
///   dart test -t flutter_e2e
///
/// Skipped automatically when `flutter` is not on PATH.
void main() {
  final flutter = _flutterAvailable();

  test(
    'create clean+bloc app, generate, analyze, and test',
    () async {
      final root = await Directory.systemTemp.createTemp('devkit_e2e_');
      addTearDown(() async {
        if (root.existsSync()) await root.delete(recursive: true);
      });

      final pkg = Directory.current.path;
      final project = p.join(root.path, 'e2e_app');

      final create = await Process.run(
        'dart',
        [
          'run',
          p.join(pkg, 'bin', 'devkit.dart'),
          'create',
          'e2e_app',
          '--no-interactive',
          '--architecture',
          'clean',
          '--state',
          'bloc',
          '--routing',
          'go_router',
          '--di',
          'get_it',
          '--no-example-feature',
          '--output',
          project,
        ],
        workingDirectory: pkg,
        runInShell: true,
      );
      expect(create.exitCode, 0, reason: '${create.stdout}\n${create.stderr}');

      // Material-first create (Chico opt-in via --chico / setup).
      final pubspec = File(p.join(project, 'pubspec.yaml')).readAsStringSync();
      expect(pubspec, isNot(contains('chico_ui')));
      expect(pubspec, contains('flutter_bloc'));
      expect(pubspec, contains('go_router'));
      expect(
        File(p.join(project, '.chico', 'devkit.yaml')).existsSync(),
        isTrue,
      );
      expect(File(p.join(project, 'lib', 'main.dart')).existsSync(), isTrue);
      final appSource = File(
        p.join(project, 'lib', 'app.dart'),
      ).readAsStringSync();
      expect(appSource, contains('MaterialApp'));
      expect(appSource, isNot(contains('ChicoApp')));

      Future<ProcessResult> devkit(List<String> args) {
        return Process.run(
          'dart',
          ['run', p.join(pkg, 'bin', 'devkit.dart'), ...args],
          workingDirectory: project,
          runInShell: true,
        );
      }

      final feature = await devkit([
        'generate',
        'feature',
        'products',
        '--no-tests',
      ]);
      expect(
        feature.exitCode,
        0,
        reason: '${feature.stdout}\n${feature.stderr}',
      );
      expect(
        feature.stdout.toString(),
        contains('in-memory'),
        reason: 'Feature summary should mention seeded in-memory data',
      );
      final entity = File(
        p.join(
          project,
          'lib',
          'features',
          'products',
          'domain',
          'entities',
          'products.dart',
        ),
      );
      expect(entity.existsSync(), isTrue);
      expect(entity.readAsStringSync(), contains('class Products'));

      final model = await devkit([
        'generate',
        'model',
        'Sku',
        '--fields',
        'id:String,code:String',
        '--no-tests',
      ]);
      expect(model.exitCode, 0, reason: '${model.stdout}\n${model.stderr}');
      final sku = File(p.join(project, 'lib', 'models', 'sku.dart'));
      expect(sku.existsSync(), isTrue);
      expect(sku.readAsStringSync(), contains('class Sku'));
      expect(sku.readAsStringSync(), contains('String id'));

      final screen = await devkit([
        'generate',
        'screen',
        'SkuDetails',
        '--no-tests',
      ]);
      expect(screen.exitCode, 0, reason: '${screen.stdout}\n${screen.stderr}');
      final screenMatches = await Directory(p.join(project, 'lib'))
          .list(recursive: true)
          .where((e) => e.path.contains('sku_details'))
          .toList();
      expect(
        screenMatches,
        isNotEmpty,
        reason: 'SkuDetails screen file missing',
      );
      final screenSource = File(screenMatches.first.path).readAsStringSync();
      expect(screenSource, contains('SkuDetailsPage'));

      final bloc = await devkit([
        'generate',
        'bloc',
        'Inventory',
        '--no-tests',
      ]);
      expect(bloc.exitCode, 0, reason: '${bloc.stdout}\n${bloc.stderr}');
      final blocMatches = await Directory(p.join(project, 'lib'))
          .list(recursive: true)
          .where((e) => e.path.contains('inventory_bloc.dart'))
          .toList();
      expect(blocMatches, isNotEmpty);
      expect(
        File(blocMatches.first.path).readAsStringSync(),
        contains('InventoryBloc'),
      );

      final format = await Process.run(
        'dart',
        ['format', 'lib', 'test'],
        workingDirectory: project,
        runInShell: true,
      );
      expect(format.exitCode, 0);

      final analyze = await Process.run(
        'flutter',
        ['analyze', '--fatal-infos'],
        workingDirectory: project,
        runInShell: true,
      );
      expect(
        analyze.exitCode,
        0,
        reason: '${analyze.stdout}\n${analyze.stderr}',
      );

      final testResult = await Process.run(
        'flutter',
        ['test'],
        workingDirectory: project,
        runInShell: true,
      );
      expect(
        testResult.exitCode,
        0,
        reason: '${testResult.stdout}\n${testResult.stderr}',
      );
    },
    skip: flutter ? false : 'Flutter SDK not available on PATH',
    timeout: const Timeout(Duration(minutes: 12)),
  );

  test(
    'repository fails closed without feature; widget generates under Flutter',
    () async {
      final root = await Directory.systemTemp.createTemp('devkit_e2e_focus_');
      addTearDown(() async {
        if (root.existsSync()) await root.delete(recursive: true);
      });

      final pkg = Directory.current.path;
      final project = p.join(root.path, 'focus_app');

      final create = await Process.run(
        'dart',
        [
          'run',
          p.join(pkg, 'bin', 'devkit.dart'),
          'create',
          'focus_app',
          '--no-interactive',
          '--architecture',
          'feature_first',
          '--state',
          'cubit',
          '--no-example-feature',
          '--output',
          project,
        ],
        workingDirectory: pkg,
        runInShell: true,
      );
      expect(create.exitCode, 0, reason: '${create.stdout}\n${create.stderr}');

      Future<ProcessResult> devkit(List<String> args) {
        return Process.run(
          'dart',
          ['run', p.join(pkg, 'bin', 'devkit.dart'), ...args],
          workingDirectory: project,
          runInShell: true,
        );
      }

      final repoFail = await devkit([
        'generate',
        'repository',
        'Orphan',
        '--no-tests',
      ]);
      expect(repoFail.exitCode, isNot(0));
      expect(
        '${repoFail.stdout}\n${repoFail.stderr}',
        contains('prerequisites'),
      );

      final feature = await devkit([
        'generate',
        'feature',
        'catalog',
        '--no-tests',
      ]);
      expect(
        feature.exitCode,
        0,
        reason: '${feature.stdout}\n${feature.stderr}',
      );

      final widget = await devkit([
        'generate',
        'widget',
        'PriceTag',
        '--no-tests',
      ]);
      expect(widget.exitCode, 0, reason: '${widget.stdout}\n${widget.stderr}');
      final widgetFiles = await Directory(p.join(project, 'lib'))
          .list(recursive: true)
          .where((e) => e.path.contains('price_tag'))
          .toList();
      expect(widgetFiles, isNotEmpty);
      expect(
        File(widgetFiles.first.path).readAsStringSync(),
        contains('PriceTag'),
      );

      final analyze = await Process.run(
        'flutter',
        ['analyze', '--fatal-infos'],
        workingDirectory: project,
        runInShell: true,
      );
      expect(
        analyze.exitCode,
        0,
        reason: '${analyze.stdout}\n${analyze.stderr}',
      );
    },
    skip: flutter ? false : 'Flutter SDK not available on PATH',
    timeout: const Timeout(Duration(minutes: 12)),
  );

  test(
    'generate api + feature --from-api + auth analyze clean',
    () async {
      final root = await Directory.systemTemp.createTemp('devkit_e2e_api_');
      addTearDown(() async {
        if (root.existsSync()) await root.delete(recursive: true);
      });

      final pkg = Directory.current.path;
      final project = p.join(root.path, 'api_app');
      final create = await Process.run(
        'dart',
        [
          'run',
          p.join(pkg, 'bin', 'devkit.dart'),
          'create',
          'api_app',
          '--no-interactive',
          '--architecture',
          'clean',
          '--state',
          'bloc',
          '--no-example-feature',
          '--output',
          project,
        ],
        workingDirectory: pkg,
        runInShell: true,
      );
      expect(create.exitCode, 0, reason: '${create.stdout}\n${create.stderr}');

      Future<ProcessResult> devkit(List<String> args) {
        return Process.run(
          'dart',
          ['run', p.join(pkg, 'bin', 'devkit.dart'), ...args],
          workingDirectory: project,
          runInShell: true,
        );
      }

      final specSrc = p.join(
        pkg,
        'test',
        'fixtures',
        'openapi',
        'shop_api.yaml',
      );
      final specDir = Directory(p.join(project, 'openapi'));
      await specDir.create(recursive: true);
      await File(specSrc).copy(p.join(specDir.path, 'shop_api.yaml'));

      final api = await devkit([
        'generate',
        'api',
        'shop',
        '--spec',
        'openapi/shop_api.yaml',
      ]);
      expect(api.exitCode, 0, reason: '${api.stdout}\n${api.stderr}');

      final feature = await devkit([
        'generate',
        'feature',
        'products',
        '--from-api',
        'shop',
        '--pagination',
        '--search',
        '--no-tests',
      ]);
      expect(
        feature.exitCode,
        0,
        reason: '${feature.stdout}\n${feature.stderr}',
      );
      expect(feature.stdout.toString(), contains('ShopApi'));
      final remote = File(
        p.join(
          project,
          'lib',
          'features',
          'products',
          'data',
          'datasources',
          'products_remote_datasource.dart',
        ),
      ).readAsStringSync();
      expect(remote, contains('listProducts'));
      expect(remote, isNot(contains('demo in-memory')));

      final auth = await devkit(['generate', 'auth', 'session']);
      expect(auth.exitCode, 0, reason: '${auth.stdout}\n${auth.stderr}');

      final missing = await devkit([
        'generate',
        'feature',
        'orders',
        '--from-api',
        'nope',
        '--no-tests',
      ]);
      expect(missing.exitCode, isNot(0));

      final analyze = await Process.run(
        'flutter',
        ['analyze', '--fatal-infos'],
        workingDirectory: project,
        runInShell: true,
      );
      expect(
        analyze.exitCode,
        0,
        reason: '${analyze.stdout}\n${analyze.stderr}',
      );
    },
    skip: flutter ? false : 'Flutter SDK not available on PATH',
    timeout: const Timeout(Duration(minutes: 12)),
  );

  test(
    'feature --spec + custom region sync + auth --ui + flutter test',
    () async {
      final root = await Directory.systemTemp.createTemp('devkit_e2e_120_');
      addTearDown(() async {
        if (root.existsSync()) await root.delete(recursive: true);
      });

      final pkg = Directory.current.path;
      final project = p.join(root.path, 'spec_app');
      final create = await Process.run(
        'dart',
        [
          'run',
          p.join(pkg, 'bin', 'devkit.dart'),
          'create',
          'spec_app',
          '--no-interactive',
          '--architecture',
          'clean',
          '--state',
          'bloc',
          '--routing',
          'go_router',
          '--di',
          'get_it',
          '--no-example-feature',
          '--output',
          project,
        ],
        workingDirectory: pkg,
        runInShell: true,
      );
      expect(create.exitCode, 0, reason: '${create.stdout}\n${create.stderr}');

      Future<ProcessResult> devkit(List<String> args) {
        return Process.run(
          'dart',
          ['run', p.join(pkg, 'bin', 'devkit.dart'), ...args],
          workingDirectory: project,
          runInShell: true,
        );
      }

      final specSrc = p.join(
        pkg,
        'test',
        'fixtures',
        'openapi',
        'shop_api.yaml',
      );
      final specDir = Directory(p.join(project, 'openapi'));
      await specDir.create(recursive: true);
      await File(specSrc).copy(p.join(specDir.path, 'shop_api.yaml'));

      final feature = await devkit([
        'generate',
        'feature',
        'products',
        '--spec',
        'openapi/shop_api.yaml',
        '--api-name',
        'shop',
        '--pagination',
        '--search',
      ]);
      expect(
        feature.exitCode,
        0,
        reason: '${feature.stdout}\n${feature.stderr}',
      );
      expect(feature.stdout.toString(), contains('ShopApi'));
      expect(
        File(
          p.join(project, 'lib', 'api', 'shop', 'generated', 'client.dart'),
        ).existsSync(),
        isTrue,
      );

      final home = File(
        p.join(
          project,
          'lib',
          'features',
          'home',
          'presentation',
          'pages',
          'home_page.dart',
        ),
      ).readAsStringSync();
      expect(home.toLowerCase(), contains('product'));

      final remotePath = p.join(
        project,
        'lib',
        'features',
        'products',
        'data',
        'datasources',
        'products_remote_datasource.dart',
      );
      final remote = File(remotePath).readAsStringSync();
      expect(remote, contains('devkit:custom id="remote.map"'));
      await File(remotePath).writeAsString(
        remote.replaceFirst(
          '// Customize DTO → model mapping\n',
          '    // E2E_CUSTOM_KEEP\n',
        ),
      );

      final sync = await devkit([
        'generate',
        'feature',
        'products',
        '--spec',
        'openapi/shop_api.yaml',
        '--api-name',
        'shop',
        '--pagination',
        '--search',
        '--sync',
      ]);
      expect(sync.exitCode, 0, reason: '${sync.stdout}\n${sync.stderr}');
      expect(File(remotePath).readAsStringSync(), contains('E2E_CUSTOM_KEEP'));

      final authUi = await devkit(['generate', 'auth', 'session', '--ui']);
      expect(authUi.exitCode, 0, reason: '${authUi.stdout}\n${authUi.stderr}');
      expect(
        File(
          p.join(
            project,
            'lib',
            'features',
            'auth',
            'presentation',
            'pages',
            'login_page.dart',
          ),
        ).existsSync(),
        isTrue,
      );

      final analyze = await Process.run(
        'flutter',
        ['analyze', '--fatal-infos'],
        workingDirectory: project,
        runInShell: true,
      );
      expect(
        analyze.exitCode,
        0,
        reason: '${analyze.stdout}\n${analyze.stderr}',
      );

      final testResult = await Process.run(
        'flutter',
        ['test'],
        workingDirectory: project,
        runInShell: true,
      );
      expect(
        testResult.exitCode,
        0,
        reason: '${testResult.stdout}\n${testResult.stderr}',
      );
    },
    skip: flutter ? false : 'Flutter SDK not available on PATH',
    timeout: const Timeout(Duration(minutes: 15)),
  );
}

bool _flutterAvailable() {
  try {
    final result = Process.runSync('flutter', ['--version'], runInShell: true);
    return result.exitCode == 0;
  } catch (_) {
    return false;
  }
}
