import '../core/exceptions.dart';
import 'defaults.dart';
import 'models.dart';

/// Parses a YAML map into a validated [DevKitConfig].
final class DevKitConfigParser {
  const DevKitConfigParser();

  DevKitConfig parse(Map<dynamic, dynamic> raw) {
    try {
      final schemaVersion = _readInt(
        raw,
        'schemaVersion',
        defaultValue: currentSchemaVersion,
      );

      final projectRaw = _readMap(raw, 'project', required: false);
      final flutterRaw = _readMap(raw, 'flutter', required: false);
      final chicoRaw = _readMap(raw, 'chico', required: false);
      final featuresRaw = _readMap(raw, 'features', required: false);
      final codeStyleRaw = _readMap(raw, 'code_style', required: false);
      final generationRaw = _readMap(raw, 'generation', required: false);

      final defaults = DevKitConfigDefaults.create();

      return DevKitConfig(
        schemaVersion: schemaVersion,
        project: _parseProject(projectRaw, defaults.project),
        flutter: _parseFlutter(flutterRaw, defaults.flutter),
        chico: _parseChico(chicoRaw, defaults.chico),
        features: _parseFeatures(featuresRaw, defaults.features),
        codeStyle: _parseCodeStyle(codeStyleRaw, defaults.codeStyle),
        generation: _parseGeneration(generationRaw, defaults.generation),
      );
    } on FormatException catch (error) {
      throw ConfigException(
        'Invalid DevKit configuration.',
        details: error.message,
        cause: error,
      );
    } on ConfigException {
      rethrow;
    } catch (error) {
      throw ConfigException(
        'Failed to parse DevKit configuration.',
        details: error.toString(),
        cause: error,
      );
    }
  }

  ProjectConfig _parseProject(
    Map<dynamic, dynamic>? raw,
    ProjectConfig defaults,
  ) {
    if (raw == null) return defaults;
    return ProjectConfig(
      name: _readString(raw, 'name', defaultValue: defaults.name),
      architecture: Architecture.parse(
        _readString(
          raw,
          'architecture',
          defaultValue: defaults.architecture.yamlValue,
        ),
      ),
      organization: _readString(
        raw,
        'organization',
        defaultValue: defaults.organization,
      ),
    );
  }

  FlutterStackConfig _parseFlutter(
    Map<dynamic, dynamic>? raw,
    FlutterStackConfig defaults,
  ) {
    if (raw == null) return defaults;

    final localizationRaw = _readMap(raw, 'localization', required: false);
    final localization = LocalizationConfig(
      enabled: _readBool(
        localizationRaw ?? const {},
        'enabled',
        defaultValue: defaults.localization.enabled,
      ),
      languages: _readStringList(
        localizationRaw ?? const {},
        'languages',
        defaultValue: defaults.localization.languages,
      ),
    );

    return FlutterStackConfig(
      stateManagement: StateManagement.parse(
        _readString(
          raw,
          'state_management',
          defaultValue: defaults.stateManagement.yamlValue,
        ),
      ),
      routing: Routing.parse(
        _readString(raw, 'routing', defaultValue: defaults.routing.yamlValue),
      ),
      dependencyInjection: DependencyInjection.parse(
        _readString(
          raw,
          'dependency_injection',
          defaultValue: defaults.dependencyInjection.yamlValue,
        ),
      ),
      localization: localization,
    );
  }

  ChicoIntegrationsConfig _parseChico(
    Map<dynamic, dynamic>? raw,
    ChicoIntegrationsConfig defaults,
  ) {
    if (raw == null) return defaults;
    return ChicoIntegrationsConfig(
      ui: _parseToggle(_readMap(raw, 'ui', required: false), defaults.ui),
      kit: _parseToggle(_readMap(raw, 'kit', required: false), defaults.kit),
      services: _parseToggle(
        _readMap(raw, 'services', required: false),
        defaults.services,
      ),
    );
  }

  ChicoPackageToggle _parseToggle(
    Map<dynamic, dynamic>? raw,
    ChicoPackageToggle defaults,
  ) {
    if (raw == null) return defaults;
    return ChicoPackageToggle(
      enabled: _readBool(raw, 'enabled', defaultValue: defaults.enabled),
      version: raw.containsKey('version')
          ? _readString(raw, 'version', defaultValue: defaults.version ?? '')
          : defaults.version,
    );
  }

  FeaturesConfig _parseFeatures(
    Map<dynamic, dynamic>? raw,
    FeaturesConfig defaults,
  ) {
    if (raw == null) return defaults;
    return FeaturesConfig(
      defaultArchitecture: Architecture.parse(
        _readString(
          raw,
          'default_architecture',
          defaultValue: defaults.defaultArchitecture.yamlValue,
        ),
      ),
      generateTests: _readBool(
        raw,
        'generate_tests',
        defaultValue: defaults.generateTests,
      ),
      generateDocumentation: _readBool(
        raw,
        'generate_documentation',
        defaultValue: defaults.generateDocumentation,
      ),
    );
  }

  CodeStyleConfig _parseCodeStyle(
    Map<dynamic, dynamic>? raw,
    CodeStyleConfig defaults,
  ) {
    if (raw == null) return defaults;
    return CodeStyleConfig(
      trailingCommas: _readBool(
        raw,
        'trailing_commas',
        defaultValue: defaults.trailingCommas,
      ),
      preferConst: _readBool(
        raw,
        'prefer_const',
        defaultValue: defaults.preferConst,
      ),
      lineLength: _readInt(
        raw,
        'line_length',
        defaultValue: defaults.lineLength,
      ),
    );
  }

  GenerationConfig _parseGeneration(
    Map<dynamic, dynamic>? raw,
    GenerationConfig defaults,
  ) {
    if (raw == null) return defaults;
    return GenerationConfig(
      overwrite: _readBool(raw, 'overwrite', defaultValue: defaults.overwrite),
      createBackups: _readBool(
        raw,
        'create_backups',
        defaultValue: defaults.createBackups,
      ),
    );
  }

  Map<dynamic, dynamic>? _readMap(
    Map<dynamic, dynamic> parent,
    String key, {
    required bool required,
  }) {
    if (!parent.containsKey(key) || parent[key] == null) {
      if (required) {
        throw FormatException('Missing required section "$key".');
      }
      return null;
    }
    final value = parent[key];
    if (value is! Map) {
      throw FormatException('Expected "$key" to be a map.');
    }
    return Map<dynamic, dynamic>.from(value);
  }

  String _readString(
    Map<dynamic, dynamic> parent,
    String key, {
    required String defaultValue,
  }) {
    if (!parent.containsKey(key) || parent[key] == null) {
      return defaultValue;
    }
    final value = parent[key];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('Expected "$key" to be a non-empty string.');
    }
    return value.trim();
  }

  bool _readBool(
    Map<dynamic, dynamic> parent,
    String key, {
    required bool defaultValue,
  }) {
    if (!parent.containsKey(key) || parent[key] == null) {
      return defaultValue;
    }
    final value = parent[key];
    if (value is! bool) {
      throw FormatException('Expected "$key" to be a boolean.');
    }
    return value;
  }

  int _readInt(
    Map<dynamic, dynamic> parent,
    String key, {
    required int defaultValue,
  }) {
    if (!parent.containsKey(key) || parent[key] == null) {
      return defaultValue;
    }
    final value = parent[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    throw FormatException('Expected "$key" to be an integer.');
  }

  List<String> _readStringList(
    Map<dynamic, dynamic> parent,
    String key, {
    required List<String> defaultValue,
  }) {
    if (!parent.containsKey(key) || parent[key] == null) {
      return List<String>.from(defaultValue);
    }
    final value = parent[key];
    if (value is! List) {
      throw FormatException('Expected "$key" to be a list of strings.');
    }
    final result = <String>[];
    for (final item in value) {
      if (item is! String || item.trim().isEmpty) {
        throw FormatException('Expected "$key" items to be non-empty strings.');
      }
      result.add(item.trim());
    }
    return result;
  }
}
