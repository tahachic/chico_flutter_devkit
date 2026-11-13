import 'dart:io';

import 'package:path/path.dart' as p;

import '../core/exceptions.dart';
import '../integrations/chico/chico_packages.dart';
import '../pubspec/pubspec_editor.dart';
import 'tool_runner.dart';

/// High-level quality operations for a Flutter project.
final class QualityService {
  QualityService({required this.toolRunner});

  final ToolRunner toolRunner;

  Future<ToolRunResult> analyze(String projectRoot, {bool fatalInfos = false}) {
    _ensureFlutterProject(projectRoot);
    return toolRunner.run([
      'flutter',
      'analyze',
      if (fatalInfos) '--fatal-infos',
    ], workingDirectory: projectRoot);
  }

  Future<ToolRunResult> format(
    String projectRoot, {
    bool setExitIfChanged = false,
  }) async {
    _ensureFlutterProject(projectRoot);
    final targets = <String>[
      for (final relative in ['lib', 'test', 'bin'])
        if (Directory(p.join(projectRoot, relative)).existsSync()) relative,
    ];
    if (targets.isEmpty) {
      return const ToolRunResult(
        exitCode: 0,
        stdout: 'Nothing to format.',
        stderr: '',
        command: ['dart', 'format'],
      );
    }
    return toolRunner.run([
      'dart',
      'format',
      if (setExitIfChanged) '--set-exit-if-changed',
      ...targets,
    ], workingDirectory: projectRoot);
  }

  Future<ToolRunResult> test(String projectRoot, {bool coverage = false}) {
    _ensureFlutterProject(projectRoot);
    return toolRunner.run([
      'flutter',
      'test',
      if (coverage) '--coverage',
    ], workingDirectory: projectRoot);
  }

  Future<ToolRunResult> clean(String projectRoot) {
    _ensureFlutterProject(projectRoot);
    return toolRunner.run(const [
      'flutter',
      'clean',
    ], workingDirectory: projectRoot);
  }

  /// Upgrades DevKit-managed Chico package constraints when newer defaults exist.
  Future<UpgradeResult> upgrade(
    String projectRoot, {
    bool dryRun = false,
  }) async {
    _ensureFlutterProject(projectRoot);
    final editor = PubspecEditor.forProject(projectRoot);
    final deps = await editor.listDependencies();
    final planned = <String>[];
    final applied = <String>[];

    for (final package in ChicoPackageId.values) {
      if (!deps.containsKey(package.packageName)) continue;
      final current = deps[package.packageName]!;
      if (current == package.defaultConstraint) continue;
      planned.add(
        '${package.packageName}: $current -> ${package.defaultConstraint}',
      );
      if (!dryRun) {
        await editor.ensureDependency(
          packageName: package.packageName,
          constraint: package.defaultConstraint,
        );
        applied.add(package.packageName);
      }
    }

    ToolRunResult? pubGet;
    if (!dryRun && applied.isNotEmpty) {
      pubGet = await toolRunner.run(const [
        'flutter',
        'pub',
        'get',
      ], workingDirectory: projectRoot);
    }

    return UpgradeResult(
      planned: planned,
      applied: applied,
      dryRun: dryRun,
      pubGet: pubGet,
    );
  }

  void _ensureFlutterProject(String projectRoot) {
    final pubspec = File(p.join(projectRoot, 'pubspec.yaml'));
    if (!pubspec.existsSync()) {
      throw ExecutionException(
        'Not a Flutter/Dart project.',
        details: 'Missing ${pubspec.path}',
      );
    }
  }
}

final class UpgradeResult {
  const UpgradeResult({
    required this.planned,
    required this.applied,
    required this.dryRun,
    this.pubGet,
  });

  final List<String> planned;
  final List<String> applied;
  final bool dryRun;
  final ToolRunResult? pubGet;
}
