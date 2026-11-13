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

      // Project creation + Chico deps (content, not only exit code).
      final pubspec = File(p.join(project, 'pubspec.yaml')).readAsStringSync();
      expect(pubspec, contains('chico_ui'));
      expect(pubspec, contains('chico_kit'));
      expect(pubspec, contains('chico_services'));
      expect(pubspec, contains('flutter_bloc'));
      expect(pubspec, contains('go_router'));
      expect(
        File(p.join(project, '.chico', 'devkit.yaml')).existsSync(),
        isTrue,
      );
      expect(File(p.join(project, 'lib', 'main.dart')).existsSync(), isTrue);

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
        contains('scaffold'),
        reason: 'Feature summary should admit scaffolding',
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
}

bool _flutterAvailable() {
  try {
    final result = Process.runSync('flutter', ['--version'], runInShell: true);
    return result.exitCode == 0;
  } catch (_) {
    return false;
  }
}
