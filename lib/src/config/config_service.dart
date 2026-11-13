import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import '../core/exceptions.dart';
import 'config_paths.dart';
import 'defaults.dart';
import 'migrator.dart';
import 'models.dart';
import 'overrides.dart';
import 'parser.dart';
import 'serializer.dart';
import 'validator.dart';

/// Result of resolving configuration from defaults + user + project + CLI.
final class ResolvedConfig {
  const ResolvedConfig({
    required this.config,
    required this.projectRoot,
    required this.projectConfigPath,
    required this.userConfigPath,
    required this.projectConfigExists,
    required this.userConfigExists,
  });

  final DevKitConfig config;
  final String projectRoot;
  final String projectConfigPath;
  final String userConfigPath;
  final bool projectConfigExists;
  final bool userConfigExists;
}

/// Loads, merges, validates, and writes DevKit configuration.
final class ConfigService {
  ConfigService({
    DevKitConfigParser? parser,
    DevKitConfigValidator? validator,
    DevKitConfigMigrator? migrator,
    DevKitConfigSerializer? serializer,
    String? homeOverride,
  }) : _parser = parser ?? const DevKitConfigParser(),
       _validator = validator ?? const DevKitConfigValidator(),
       _migrator = migrator ?? const DevKitConfigMigrator(),
       _serializer = serializer ?? const DevKitConfigSerializer(),
       _homeOverride = homeOverride;

  final DevKitConfigParser _parser;
  final DevKitConfigValidator _validator;
  final DevKitConfigMigrator _migrator;
  final DevKitConfigSerializer _serializer;
  final String? _homeOverride;

  /// Resolves configuration for [projectRoot].
  ///
  /// Merge order: defaults → user → project → [overrides].
  ResolvedConfig resolve({
    required String projectRoot,
    ConfigOverrides overrides = const ConfigOverrides(),
    String? projectNameHint,
  }) {
    final normalizedRoot = p.normalize(projectRoot);
    final projectPath = ConfigPaths.projectConfigFile(normalizedRoot);
    final userPath = ConfigPaths.userConfigFile(homeOverride: _homeOverride);

    var config = DevKitConfigDefaults.create(
      projectName:
          projectNameHint ??
          p.basename(normalizedRoot).replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_'),
    );

    final userExists = File(userPath).existsSync();
    if (userExists) {
      config = _mergeMaps(config, _loadFile(userPath));
    }

    final projectExists = File(projectPath).existsSync();
    if (projectExists) {
      config = _mergeMaps(config, _loadFile(projectPath));
    }

    config = _migrator.migrate(config);
    config = overrides.apply(config);
    _validator.validate(config);

    return ResolvedConfig(
      config: config,
      projectRoot: normalizedRoot,
      projectConfigPath: projectPath,
      userConfigPath: userPath,
      projectConfigExists: projectExists,
      userConfigExists: userExists,
    );
  }

  /// Writes a new project config unless one already exists.
  Future<String> initProjectConfig({
    required String projectRoot,
    DevKitConfig? config,
    bool force = false,
  }) async {
    final dir = Directory(ConfigPaths.projectConfigDir(projectRoot));
    final file = File(ConfigPaths.projectConfigFile(projectRoot));

    if (file.existsSync() && !force) {
      throw ConfigException(
        'Configuration already exists at ${file.path}.',
        details: 'Use --force to overwrite, or edit the file manually.',
      );
    }

    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }

    final effective =
        config ??
        DevKitConfigDefaults.create(
          projectName: p
              .basename(p.normalize(projectRoot))
              .replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_')
              .toLowerCase(),
        );
    _validator.validate(effective);

    await file.writeAsString(_serializer.toYaml(effective));
    return file.path;
  }

  /// Updates a single dotted key in the project config file.
  Future<DevKitConfig> setProjectValue({
    required String projectRoot,
    required String key,
    required String value,
  }) async {
    final resolved = resolve(projectRoot: projectRoot);
    if (!resolved.projectConfigExists) {
      throw const ConfigException(
        'No project configuration found.',
        details: 'Run `devkit config init` first.',
      );
    }

    final updated = _applyDotPath(resolved.config, key, value);
    _validator.validate(updated);

    final file = File(resolved.projectConfigPath);
    await file.writeAsString(_serializer.toYaml(updated));
    return updated;
  }

  String serialize(DevKitConfig config) => _serializer.toYaml(config);

  Map<dynamic, dynamic> _loadFile(String path) {
    try {
      final content = File(path).readAsStringSync();
      if (content.trim().isEmpty) {
        return <dynamic, dynamic>{};
      }
      final loaded = loadYaml(content);
      if (loaded == null) {
        return <dynamic, dynamic>{};
      }
      if (loaded is! YamlMap) {
        throw ConfigException(
          'Configuration root must be a YAML map.',
          details: 'File: $path',
        );
      }
      return _yamlToMap(loaded);
    } on ConfigException {
      rethrow;
    } on FileSystemException catch (error) {
      throw ConfigException(
        'Unable to read configuration file.',
        details: '${error.message}: ${error.path}',
        cause: error,
      );
    } on YamlException catch (error) {
      throw ConfigException(
        'Invalid YAML in configuration file.',
        details: '$path\n${error.message}',
        cause: error,
      );
    }
  }

  DevKitConfig _mergeMaps(DevKitConfig base, Map<dynamic, dynamic> overlay) {
    final baseMap = _deepCopyMap(base.toYamlMap());
    final merged = _deepMerge(baseMap, overlay);
    return _parser.parse(merged);
  }

  Map<dynamic, dynamic> _yamlToMap(YamlMap yaml) {
    final result = <dynamic, dynamic>{};
    for (final entry in yaml.entries) {
      result[entry.key] = _yamlValue(entry.value);
    }
    return result;
  }

  Object? _yamlValue(Object? value) {
    if (value is YamlMap) return _yamlToMap(value);
    if (value is YamlList) {
      return value.map(_yamlValue).toList(growable: false);
    }
    return value;
  }

  Map<dynamic, dynamic> _deepCopyMap(Map<String, Object?> source) {
    final result = <dynamic, dynamic>{};
    for (final entry in source.entries) {
      result[entry.key] = _deepCopyValue(entry.value);
    }
    return result;
  }

  Object? _deepCopyValue(Object? value) {
    if (value is Map) {
      return _deepCopyMap(Map<String, Object?>.from(value));
    }
    if (value is List) {
      return value.map(_deepCopyValue).toList();
    }
    return value;
  }

  Map<dynamic, dynamic> _deepMerge(
    Map<dynamic, dynamic> base,
    Map<dynamic, dynamic> overlay,
  ) {
    final result = Map<dynamic, dynamic>.from(base);
    for (final entry in overlay.entries) {
      final key = entry.key;
      final overlayValue = entry.value;
      final baseValue = result[key];
      if (baseValue is Map && overlayValue is Map) {
        result[key] = _deepMerge(
          Map<dynamic, dynamic>.from(baseValue),
          Map<dynamic, dynamic>.from(overlayValue),
        );
      } else {
        result[key] = overlayValue;
      }
    }
    return result;
  }

  DevKitConfig _applyDotPath(DevKitConfig config, String key, String value) {
    final parts = key.split('.').where((part) => part.isNotEmpty).toList();
    if (parts.isEmpty) {
      throw const ConfigException('Config key must not be empty.');
    }

    final map = _deepCopyMap(config.toYamlMap());
    Map<dynamic, dynamic> cursor = map;
    for (var i = 0; i < parts.length - 1; i++) {
      final part = parts[i];
      final next = cursor[part];
      if (next is! Map) {
        throw ConfigException(
          'Cannot set "$key".',
          details: 'Path segment "$part" is not a map.',
        );
      }
      final nested = Map<dynamic, dynamic>.from(next);
      cursor[part] = nested;
      cursor = nested;
    }

    final leaf = parts.last;
    cursor[leaf] = _coerceScalar(value);
    return _parser.parse(map);
  }

  Object _coerceScalar(String value) {
    final trimmed = value.trim();
    if (trimmed == 'true') return true;
    if (trimmed == 'false') return false;
    final asInt = int.tryParse(trimmed);
    if (asInt != null) return asInt;
    if (trimmed.startsWith('[') && trimmed.endsWith(']')) {
      final inner = trimmed.substring(1, trimmed.length - 1).trim();
      if (inner.isEmpty) return <String>[];
      return inner.split(',').map((item) => item.trim()).toList();
    }
    return trimmed;
  }
}
