import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';

import '../core/exceptions.dart';

/// Abstraction over the Flutter CLI for testability.
abstract interface class FlutterCli {
  Future<void> createProject({
    required String name,
    required String organization,
    required String outputDirectory,
  });

  Future<void> pubGet(String projectRoot);

  /// Runs `flutter gen-l10n` when the project has `l10n.yaml`.
  Future<void> genL10n(String projectRoot);

  /// Whether this Flutter SDK should use standalone `material_ui` (≥ 3.47).
  Future<bool> supportsMaterialUiPackage();

  /// Runs `dart fix --apply --code=migrate_design_widgets` in [projectRoot].
  Future<void> migrateDesignWidgets(String projectRoot);
}

/// Real Flutter CLI implementation using `Process`.
final class ProcessFlutterCli implements FlutterCli {
  ProcessFlutterCli({this.flutterExecutable = 'flutter'});

  final String flutterExecutable;

  @override
  Future<void> createProject({
    required String name,
    required String organization,
    required String outputDirectory,
  }) async {
    final parent = Directory(outputDirectory).parent.path;
    await Directory(parent).create(recursive: true);

    final result = await Process.run(flutterExecutable, [
      'create',
      '--project-name',
      name,
      '--org',
      organization,
      '--platforms',
      'android,ios,web',
      outputDirectory,
    ], runInShell: true);

    if (result.exitCode != 0) {
      throw ExecutionException(
        'flutter create failed.',
        details: '${result.stderr}\n${result.stdout}',
      );
    }
  }

  @override
  Future<void> pubGet(String projectRoot) async {
    final result = await Process.run(
      flutterExecutable,
      const ['pub', 'get'],
      workingDirectory: projectRoot,
      runInShell: true,
    );
    if (result.exitCode != 0) {
      throw ExecutionException(
        'flutter pub get failed.',
        details: '${result.stderr}\n${result.stdout}',
      );
    }
  }

  @override
  Future<void> genL10n(String projectRoot) async {
    final result = await Process.run(
      flutterExecutable,
      const ['gen-l10n'],
      workingDirectory: projectRoot,
      runInShell: true,
    );
    if (result.exitCode != 0) {
      throw ExecutionException(
        'flutter gen-l10n failed.',
        details: '${result.stderr}\n${result.stdout}',
      );
    }
  }

  @override
  Future<bool> supportsMaterialUiPackage() async {
    final result = await Process.run(flutterExecutable, [
      '--version',
      '--machine',
    ], runInShell: true);
    if (result.exitCode != 0) return false;
    try {
      final raw = (result.stdout as String).trim();
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final versionRaw = json['frameworkVersion'] as String?;
      if (versionRaw == null || versionRaw.isEmpty) return false;
      final version = Version.parse(versionRaw.split(' ').first);
      return version >= Version(3, 47, 0);
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> migrateDesignWidgets(String projectRoot) async {
    final result = await Process.run(
      'dart',
      const ['fix', '--apply', '--code=migrate_design_widgets'],
      workingDirectory: projectRoot,
      runInShell: true,
    );
    if (result.exitCode != 0) {
      throw ExecutionException(
        'dart fix migrate_design_widgets failed.',
        details: '${result.stderr}\n${result.stdout}',
      );
    }
  }
}

/// Test double that scaffolds a minimal Flutter-like project without Flutter SDK.
final class FakeFlutterCli implements FlutterCli {
  FakeFlutterCli({this.materialUiSupported = false});

  final bool materialUiSupported;
  final List<String> created = [];
  final List<String> pubGetCalls = [];
  final List<String> genL10nCalls = [];
  final List<String> migrateDesignWidgetsCalls = [];

  @override
  Future<void> createProject({
    required String name,
    required String organization,
    required String outputDirectory,
  }) async {
    created.add(outputDirectory);
    final dir = Directory(outputDirectory);
    await dir.create(recursive: true);
    await File(p.join(outputDirectory, 'pubspec.yaml')).writeAsString('''
name: $name
description: A new Flutter project.
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: ^3.8.0

dependencies:
  flutter:
    sdk: flutter

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0

flutter:
  uses-material-design: true
''');
    await Directory(p.join(outputDirectory, 'lib')).create(recursive: true);
    await File(p.join(outputDirectory, 'lib', 'main.dart')).writeAsString('''
import 'package:flutter/material.dart';

void main() {
  runApp(const MaterialApp(home: SizedBox.shrink()));
}
''');
    await Directory(p.join(outputDirectory, 'test')).create(recursive: true);
  }

  @override
  Future<void> pubGet(String projectRoot) async {
    pubGetCalls.add(projectRoot);
  }

  @override
  Future<void> genL10n(String projectRoot) async {
    genL10nCalls.add(projectRoot);
  }

  @override
  Future<bool> supportsMaterialUiPackage() async => materialUiSupported;

  @override
  Future<void> migrateDesignWidgets(String projectRoot) async {
    migrateDesignWidgetsCalls.add(projectRoot);
  }
}
