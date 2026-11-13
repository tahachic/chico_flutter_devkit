import 'dart:io';

import 'package:path/path.dart' as p;

import '../core/exceptions.dart';

/// Abstraction over the Flutter CLI for testability.
abstract interface class FlutterCli {
  Future<void> createProject({
    required String name,
    required String organization,
    required String outputDirectory,
  });

  Future<void> pubGet(String projectRoot);
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
}

/// Test double that scaffolds a minimal Flutter-like project without Flutter SDK.
final class FakeFlutterCli implements FlutterCli {
  FakeFlutterCli();

  final List<String> created = [];
  final List<String> pubGetCalls = [];

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
}
