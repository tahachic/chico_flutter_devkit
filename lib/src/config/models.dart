/// Supported application architectures.
enum Architecture {
  featureFirst('feature_first'),
  clean('clean'),
  layered('layered');

  const Architecture(this.yamlValue);
  final String yamlValue;

  static Architecture parse(String raw) {
    final normalized = raw.trim().toLowerCase().replaceAll('-', '_');
    return Architecture.values.firstWhere(
      (value) => value.yamlValue == normalized || value.name == normalized,
      orElse: () => throw FormatException(
        'Unknown architecture "$raw". '
        'Expected: feature_first, clean, layered.',
      ),
    );
  }
}

/// Supported state management options.
enum StateManagement {
  bloc('bloc'),
  cubit('cubit'),
  riverpod('riverpod'),
  provider('provider');

  const StateManagement(this.yamlValue);
  final String yamlValue;

  static StateManagement parse(String raw) {
    final normalized = raw.trim().toLowerCase();
    return StateManagement.values.firstWhere(
      (value) => value.yamlValue == normalized || value.name == normalized,
      orElse: () => throw FormatException(
        'Unknown state_management "$raw". '
        'Expected: bloc, cubit, riverpod, provider.',
      ),
    );
  }
}

/// Supported routing options.
enum Routing {
  goRouter('go_router'),
  navigator('navigator');

  const Routing(this.yamlValue);
  final String yamlValue;

  static Routing parse(String raw) {
    final normalized = raw.trim().toLowerCase().replaceAll('-', '_');
    return Routing.values.firstWhere(
      (value) => value.yamlValue == normalized || value.name == normalized,
      orElse: () => throw FormatException(
        'Unknown routing "$raw". Expected: go_router, navigator.',
      ),
    );
  }
}

/// Supported dependency injection options.
enum DependencyInjection {
  getIt('get_it'),
  riverpod('riverpod'),
  manual('manual');

  const DependencyInjection(this.yamlValue);
  final String yamlValue;

  static DependencyInjection parse(String raw) {
    final normalized = raw.trim().toLowerCase().replaceAll('-', '_');
    return DependencyInjection.values.firstWhere(
      (value) => value.yamlValue == normalized || value.name == normalized,
      orElse: () => throw FormatException(
        'Unknown dependency_injection "$raw". '
        'Expected: get_it, riverpod, manual.',
      ),
    );
  }
}

/// Project identity section.
final class ProjectConfig {
  const ProjectConfig({
    required this.name,
    required this.architecture,
    required this.organization,
  });

  final String name;
  final Architecture architecture;
  final String organization;

  ProjectConfig copyWith({
    String? name,
    Architecture? architecture,
    String? organization,
  }) {
    return ProjectConfig(
      name: name ?? this.name,
      architecture: architecture ?? this.architecture,
      organization: organization ?? this.organization,
    );
  }

  Map<String, Object?> toYamlMap() => {
    'name': name,
    'architecture': architecture.yamlValue,
    'organization': organization,
  };
}

/// Localization settings.
final class LocalizationConfig {
  const LocalizationConfig({required this.enabled, required this.languages});

  final bool enabled;
  final List<String> languages;

  LocalizationConfig copyWith({bool? enabled, List<String>? languages}) {
    return LocalizationConfig(
      enabled: enabled ?? this.enabled,
      languages: languages ?? this.languages,
    );
  }

  Map<String, Object?> toYamlMap() => {
    'enabled': enabled,
    'languages': languages,
  };
}

/// Flutter stack preferences.
final class FlutterStackConfig {
  const FlutterStackConfig({
    required this.stateManagement,
    required this.routing,
    required this.dependencyInjection,
    required this.localization,
  });

  final StateManagement stateManagement;
  final Routing routing;
  final DependencyInjection dependencyInjection;
  final LocalizationConfig localization;

  FlutterStackConfig copyWith({
    StateManagement? stateManagement,
    Routing? routing,
    DependencyInjection? dependencyInjection,
    LocalizationConfig? localization,
  }) {
    return FlutterStackConfig(
      stateManagement: stateManagement ?? this.stateManagement,
      routing: routing ?? this.routing,
      dependencyInjection: dependencyInjection ?? this.dependencyInjection,
      localization: localization ?? this.localization,
    );
  }

  Map<String, Object?> toYamlMap() => {
    'state_management': stateManagement.yamlValue,
    'routing': routing.yamlValue,
    'dependency_injection': dependencyInjection.yamlValue,
    'localization': localization.toYamlMap(),
  };
}

/// Toggle for a single Chico package.
final class ChicoPackageToggle {
  const ChicoPackageToggle({required this.enabled, this.version});

  final bool enabled;

  /// Optional pub constraint override, e.g. `^1.7.0`.
  final String? version;

  ChicoPackageToggle copyWith({bool? enabled, String? version}) {
    return ChicoPackageToggle(
      enabled: enabled ?? this.enabled,
      version: version ?? this.version,
    );
  }

  Map<String, Object?> toYamlMap() {
    return {'enabled': enabled, if (version != null) 'version': version};
  }
}

/// Chico ecosystem integration toggles.
final class ChicoIntegrationsConfig {
  const ChicoIntegrationsConfig({
    required this.ui,
    required this.kit,
    required this.services,
  });

  final ChicoPackageToggle ui;
  final ChicoPackageToggle kit;
  final ChicoPackageToggle services;

  ChicoIntegrationsConfig copyWith({
    ChicoPackageToggle? ui,
    ChicoPackageToggle? kit,
    ChicoPackageToggle? services,
  }) {
    return ChicoIntegrationsConfig(
      ui: ui ?? this.ui,
      kit: kit ?? this.kit,
      services: services ?? this.services,
    );
  }

  Map<String, Object?> toYamlMap() => {
    'ui': ui.toYamlMap(),
    'kit': kit.toYamlMap(),
    'services': services.toYamlMap(),
  };
}

/// Feature generation defaults.
final class FeaturesConfig {
  const FeaturesConfig({
    required this.defaultArchitecture,
    required this.generateTests,
    required this.generateDocumentation,
  });

  final Architecture defaultArchitecture;
  final bool generateTests;
  final bool generateDocumentation;

  FeaturesConfig copyWith({
    Architecture? defaultArchitecture,
    bool? generateTests,
    bool? generateDocumentation,
  }) {
    return FeaturesConfig(
      defaultArchitecture: defaultArchitecture ?? this.defaultArchitecture,
      generateTests: generateTests ?? this.generateTests,
      generateDocumentation:
          generateDocumentation ?? this.generateDocumentation,
    );
  }

  Map<String, Object?> toYamlMap() => {
    'default_architecture': defaultArchitecture.yamlValue,
    'generate_tests': generateTests,
    'generate_documentation': generateDocumentation,
  };
}

/// Code style preferences used by generators.
final class CodeStyleConfig {
  const CodeStyleConfig({
    required this.trailingCommas,
    required this.preferConst,
    required this.lineLength,
  });

  final bool trailingCommas;
  final bool preferConst;
  final int lineLength;

  CodeStyleConfig copyWith({
    bool? trailingCommas,
    bool? preferConst,
    int? lineLength,
  }) {
    return CodeStyleConfig(
      trailingCommas: trailingCommas ?? this.trailingCommas,
      preferConst: preferConst ?? this.preferConst,
      lineLength: lineLength ?? this.lineLength,
    );
  }

  Map<String, Object?> toYamlMap() => {
    'trailing_commas': trailingCommas,
    'prefer_const': preferConst,
    'line_length': lineLength,
  };
}

/// File generation safety settings.
final class GenerationConfig {
  const GenerationConfig({
    required this.overwrite,
    required this.createBackups,
  });

  final bool overwrite;
  final bool createBackups;

  GenerationConfig copyWith({bool? overwrite, bool? createBackups}) {
    return GenerationConfig(
      overwrite: overwrite ?? this.overwrite,
      createBackups: createBackups ?? this.createBackups,
    );
  }

  Map<String, Object?> toYamlMap() => {
    'overwrite': overwrite,
    'create_backups': createBackups,
  };
}

/// Root DevKit configuration model.
final class DevKitConfig {
  const DevKitConfig({
    required this.schemaVersion,
    required this.project,
    required this.flutter,
    required this.chico,
    required this.features,
    required this.codeStyle,
    required this.generation,
  });

  final int schemaVersion;
  final ProjectConfig project;
  final FlutterStackConfig flutter;
  final ChicoIntegrationsConfig chico;
  final FeaturesConfig features;
  final CodeStyleConfig codeStyle;
  final GenerationConfig generation;

  DevKitConfig copyWith({
    int? schemaVersion,
    ProjectConfig? project,
    FlutterStackConfig? flutter,
    ChicoIntegrationsConfig? chico,
    FeaturesConfig? features,
    CodeStyleConfig? codeStyle,
    GenerationConfig? generation,
  }) {
    return DevKitConfig(
      schemaVersion: schemaVersion ?? this.schemaVersion,
      project: project ?? this.project,
      flutter: flutter ?? this.flutter,
      chico: chico ?? this.chico,
      features: features ?? this.features,
      codeStyle: codeStyle ?? this.codeStyle,
      generation: generation ?? this.generation,
    );
  }

  Map<String, Object?> toYamlMap() => {
    'schemaVersion': schemaVersion,
    'project': project.toYamlMap(),
    'flutter': flutter.toYamlMap(),
    'chico': chico.toYamlMap(),
    'features': features.toYamlMap(),
    'code_style': codeStyle.toYamlMap(),
    'generation': generation.toYamlMap(),
  };
}
