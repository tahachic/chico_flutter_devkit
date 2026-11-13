import 'dart:io';

import '../core/exceptions.dart';

/// Result of running an external tool.
final class ToolRunResult {
  const ToolRunResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
    required this.command,
  });

  final int exitCode;
  final String stdout;
  final String stderr;
  final List<String> command;

  bool get success => exitCode == 0;
}

/// Runs Flutter/Dart tooling in a project.
abstract interface class ToolRunner {
  Future<ToolRunResult> run(
    List<String> command, {
    required String workingDirectory,
  });

  Future<bool> isFlutterAvailable();

  Future<bool> isDartAvailable();

  Future<String?> flutterVersion();

  Future<String?> dartVersion();
}

/// Process-based tool runner.
final class ProcessToolRunner implements ToolRunner {
  ProcessToolRunner({
    this.flutterExecutable = 'flutter',
    this.dartExecutable = 'dart',
  });

  final String flutterExecutable;
  final String dartExecutable;

  @override
  Future<ToolRunResult> run(
    List<String> command, {
    required String workingDirectory,
  }) async {
    if (command.isEmpty) {
      throw const ExecutionException('Tool command must not be empty.');
    }
    final executable = command.first;
    final args = command.skip(1).toList(growable: false);
    final result = await Process.run(
      executable,
      args,
      workingDirectory: workingDirectory,
      runInShell: true,
    );
    return ToolRunResult(
      exitCode: result.exitCode,
      stdout: result.stdout.toString(),
      stderr: result.stderr.toString(),
      command: command,
    );
  }

  @override
  Future<bool> isFlutterAvailable() async {
    try {
      final result = await Process.run(flutterExecutable, const [
        '--version',
      ], runInShell: true);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> isDartAvailable() async {
    try {
      final result = await Process.run(dartExecutable, const [
        '--version',
      ], runInShell: true);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<String?> flutterVersion() async {
    try {
      final result = await Process.run(flutterExecutable, const [
        '--version',
      ], runInShell: true);
      if (result.exitCode != 0) return null;
      final line = result.stdout.toString().split('\n').first.trim();
      return line.isEmpty ? null : line;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String?> dartVersion() async {
    try {
      final result = await Process.run(dartExecutable, const [
        '--version',
      ], runInShell: true);
      if (result.exitCode != 0) return null;
      final text = result.stdout.toString().trim();
      return text.isEmpty ? result.stderr.toString().trim() : text;
    } catch (_) {
      return null;
    }
  }
}

/// In-memory tool runner for tests.
final class FakeToolRunner implements ToolRunner {
  FakeToolRunner({
    this.flutterAvailable = true,
    this.dartAvailable = true,
    this.flutterVersionText = 'Flutter 3.44.4',
    this.dartVersionText = 'Dart SDK version: 3.12.2',
    Map<String, ToolRunResult>? results,
  }) : _results = results ?? {};

  final bool flutterAvailable;
  final bool dartAvailable;
  final String flutterVersionText;
  final String dartVersionText;
  final Map<String, ToolRunResult> _results;
  final List<List<String>> calls = [];

  void stub(String key, ToolRunResult result) => _results[key] = result;

  @override
  Future<ToolRunResult> run(
    List<String> command, {
    required String workingDirectory,
  }) async {
    calls.add(command);
    final key = command.join(' ');
    return _results[key] ??
        ToolRunResult(exitCode: 0, stdout: 'ok', stderr: '', command: command);
  }

  @override
  Future<bool> isFlutterAvailable() async => flutterAvailable;

  @override
  Future<bool> isDartAvailable() async => dartAvailable;

  @override
  Future<String?> flutterVersion() async =>
      flutterAvailable ? flutterVersionText : null;

  @override
  Future<String?> dartVersion() async => dartAvailable ? dartVersionText : null;
}
