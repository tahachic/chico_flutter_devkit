import 'models.dart';

/// Current configuration schema version.
const int currentSchemaVersion = 1;

/// Default published Chico package constraints (configurable per project).
abstract final class DefaultChicoVersions {
  static const String ui = '^1.7.0';
  static const String kit = '^1.4.0';
  static const String services = '^1.4.1';
}

/// Factory for validated default configuration.
abstract final class DevKitConfigDefaults {
  static DevKitConfig create({
    String projectName = 'my_application',
    String organization = 'com.example',
  }) {
    return DevKitConfig(
      schemaVersion: currentSchemaVersion,
      project: ProjectConfig(
        name: projectName,
        architecture: Architecture.clean,
        organization: organization,
      ),
      flutter: const FlutterStackConfig(
        stateManagement: StateManagement.bloc,
        routing: Routing.goRouter,
        dependencyInjection: DependencyInjection.getIt,
        localization: LocalizationConfig(enabled: true, languages: ['en']),
      ),
      chico: const ChicoIntegrationsConfig(
        // Opt-in: Material-first defaults; enable via create --chico or setup.
        ui: ChicoPackageToggle(
          enabled: false,
          version: DefaultChicoVersions.ui,
        ),
        kit: ChicoPackageToggle(
          enabled: false,
          version: DefaultChicoVersions.kit,
        ),
        services: ChicoPackageToggle(
          enabled: false,
          version: DefaultChicoVersions.services,
        ),
      ),
      features: const FeaturesConfig(
        defaultArchitecture: Architecture.clean,
        generateTests: true,
        generateDocumentation: true,
      ),
      codeStyle: const CodeStyleConfig(
        trailingCommas: true,
        preferConst: true,
        lineLength: 100,
      ),
      generation: const GenerationConfig(overwrite: false, createBackups: true),
    );
  }
}
