import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml_edit/yaml_edit.dart';

import '../core/exceptions.dart';

/// Reads and safely updates a Flutter/Dart `pubspec.yaml`.
final class PubspecEditor {
  PubspecEditor(this.file);

  factory PubspecEditor.forProject(String projectRoot) {
    return PubspecEditor(File(p.join(projectRoot, 'pubspec.yaml')));
  }

  final File file;

  Future<String> read() async {
    if (!file.existsSync()) {
      throw ExecutionException('pubspec.yaml not found.', details: file.path);
    }
    return file.readAsString();
  }

  /// Ensures [packageName] exists under `dependencies` with [constraint].
  ///
  /// Returns `true` when the file was modified.
  Future<bool> ensureDependency({
    required String packageName,
    required String constraint,
  }) async {
    final original = await read();
    final editor = YamlEditor(original);

    try {
      final current = editor.parseAt(['dependencies', packageName]);
      if (current.value?.toString() == constraint) {
        return false;
      }
      editor.update(['dependencies', packageName], constraint);
    } on ArgumentError {
      // Path missing — create dependencies map if needed, then package.
      try {
        editor.parseAt(['dependencies']);
      } on ArgumentError {
        editor.update(['dependencies'], <String, Object?>{});
      }
      editor.update(['dependencies', packageName], constraint);
    }

    final updated = editor.toString();
    if (updated == original) return false;
    await file.writeAsString(updated);
    return true;
  }

  Future<Map<String, String>> listDependencies() async {
    final content = await read();
    final editor = YamlEditor(content);
    try {
      final deps = editor.parseAt(['dependencies']);
      final value = deps.value;
      if (value is! Map) return {};
      final result = <String, String>{};
      for (final entry in value.entries) {
        final key = entry.key.toString();
        if (key == 'flutter' || key == 'flutter_test') continue;
        result[key] = entry.value.toString();
      }
      return result;
    } on ArgumentError {
      return {};
    }
  }

  Future<bool> hasDependency(String packageName) async {
    final deps = await listDependencies();
    return deps.containsKey(packageName);
  }

  /// Ensures `dependencies.<name>: { sdk: flutter }` (e.g. flutter_localizations).
  Future<bool> ensureSdkDependency(String packageName) async {
    final original = await read();
    final editor = YamlEditor(original);
    try {
      editor.parseAt(['dependencies']);
    } on ArgumentError {
      editor.update(['dependencies'], <String, Object?>{});
    }
    editor.update(['dependencies', packageName], {'sdk': 'flutter'});
    final updated = editor.toString();
    if (updated == original) return false;
    await file.writeAsString(updated);
    return true;
  }

  /// Ensures `flutter: generate: true` for gen-l10n / assets codegen.
  Future<bool> ensureFlutterGenerate({bool enabled = true}) async {
    final original = await read();
    final editor = YamlEditor(original);
    try {
      editor.parseAt(['flutter']);
    } on ArgumentError {
      editor.update(['flutter'], <String, Object?>{});
    }
    editor.update(['flutter', 'generate'], enabled);
    final updated = editor.toString();
    if (updated == original) return false;
    await file.writeAsString(updated);
    return true;
  }
}
