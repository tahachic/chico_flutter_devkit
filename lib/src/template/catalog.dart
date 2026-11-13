import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import '../config/models.dart';
import '../core/exceptions.dart';
import 'descriptor.dart';
import 'engine.dart';

/// Loads and renders templates from a filesystem catalog root.
final class TemplateCatalog {
  TemplateCatalog({required this.rootDirectory, TemplateEngine? engine})
    : _engine = engine ?? const TemplateEngine();

  final String rootDirectory;
  final TemplateEngine _engine;

  /// Loads `template.yaml` for [templateId].
  Future<TemplateDescriptor> loadDescriptor(String templateId) async {
    final dir = Directory(p.join(rootDirectory, templateId));
    final manifest = File(p.join(dir.path, 'template.yaml'));
    if (!manifest.existsSync()) {
      throw ExecutionException(
        'Template "$templateId" not found.',
        details: 'Expected manifest at ${manifest.path}',
      );
    }

    final loaded = loadYaml(await manifest.readAsString());
    if (loaded is! YamlMap) {
      throw ExecutionException(
        'Invalid template manifest for "$templateId".',
        details: 'Root must be a YAML map.',
      );
    }

    final filesRaw = loaded['files'];
    if (filesRaw is! YamlList) {
      throw ExecutionException(
        'Template "$templateId" must declare a files list.',
      );
    }

    final files = <TemplateFileSpec>[];
    for (final item in filesRaw) {
      if (item is! YamlMap) {
        throw ExecutionException(
          'Template "$templateId" has an invalid files entry.',
        );
      }
      files.add(
        TemplateFileSpec(
          templatePath: item['template']?.toString() ?? '',
          outputPath: item['output']?.toString() ?? '',
          condition: item['when']?.toString(),
        ),
      );
    }

    Architecture parseArch(String raw) => Architecture.parse(raw);
    StateManagement parseState(String raw) => StateManagement.parse(raw);

    List<T> parseList<T>(String key, T Function(String) parse) {
      final value = loaded[key];
      if (value == null) return <T>[];
      if (value is! YamlList) {
        throw ExecutionException('Template "$templateId".$key must be a list.');
      }
      return value.map((item) => parse(item.toString())).toList();
    }

    return TemplateDescriptor(
      id: loaded['id']?.toString() ?? templateId,
      version: loaded['version']?.toString() ?? '0.0.0',
      description: loaded['description']?.toString() ?? '',
      files: files,
      requiredVariables: parseList<String>(
        'required_variables',
        (value) => value,
      ),
      supportedArchitectures: parseList('architectures', parseArch),
      supportedStateManagement: parseList('state_management', parseState),
    );
  }

  /// Reads and renders a single template file.
  Future<String> renderFile({
    required String templateId,
    required String templatePath,
    required Map<String, Object?> variables,
  }) async {
    final file = File(p.join(rootDirectory, templateId, templatePath));
    if (!file.existsSync()) {
      throw ExecutionException('Template file missing.', details: file.path);
    }
    final source = await file.readAsString();
    return _engine.render(source, variables);
  }

  /// Renders all files for [descriptor] into relative-path → content.
  Future<Map<String, String>> renderAll({
    required TemplateDescriptor descriptor,
    required Map<String, Object?> variables,
  }) async {
    for (final required in descriptor.requiredVariables) {
      if (!_isPresent(variables, required)) {
        throw ExecutionException(
          'Missing required template variable "$required" '
          'for template "${descriptor.id}".',
        );
      }
    }

    final outputs = <String, String>{};
    for (final file in descriptor.files) {
      if (file.condition != null &&
          !_isTruthy(_lookup(variables, file.condition!))) {
        continue;
      }
      final content = await renderFile(
        templateId: descriptor.id,
        templatePath: file.templatePath,
        variables: variables,
      );
      final outputPath = _engine.render(file.outputPath, variables);
      outputs[outputPath] = content;
    }
    return outputs;
  }

  bool _isPresent(Map<String, Object?> variables, String key) {
    return _lookup(variables, key) != null;
  }

  Object? _lookup(Map<String, Object?> variables, String key) {
    if (variables.containsKey(key)) return variables[key];
    final parts = key.split('.');
    Object? current = variables;
    for (final part in parts) {
      if (current is Map) {
        current = current[part];
      } else {
        return null;
      }
    }
    return current;
  }

  bool _isTruthy(Object? value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is String) return value.isNotEmpty;
    if (value is Iterable) return value.isNotEmpty;
    if (value is num) return value != 0;
    return true;
  }
}
