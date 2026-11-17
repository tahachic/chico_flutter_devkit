import '../config/models.dart';
import '../naming/name_converter.dart';

/// Options for `devkit create`.
final class ProjectCreateOptions {
  ProjectCreateOptions({
    required this.name,
    required this.organization,
    required this.architecture,
    required this.stateManagement,
    required this.routing,
    required this.dependencyInjection,
    required this.enableChicoUi,
    required this.enableChicoKit,
    required this.enableChicoServices,
    required this.enableLocalization,
    this.languages = const ['en'],
    required this.enableDarkMode,
    required this.enableLogging,
    required this.enableErrorHandling,
    required this.generateExampleFeature,
    required this.outputDirectory,
    this.apiBaseUrl = 'https://api.example.com',
    this.useMaterialUi = false,
  });

  final String name;
  final String organization;
  final Architecture architecture;
  final StateManagement stateManagement;
  final Routing routing;
  final DependencyInjection dependencyInjection;
  final bool enableChicoUi;
  final bool enableChicoKit;
  final bool enableChicoServices;
  final bool enableLocalization;

  /// BCP-47 language tags for gen-l10n ARB files (template prefers `en`).
  final List<String> languages;
  final bool enableDarkMode;
  final bool enableLogging;
  final bool enableErrorHandling;
  final bool generateExampleFeature;
  final String outputDirectory;
  final String apiBaseUrl;

  /// Use `package:material_ui` instead of deprecated `flutter/material.dart`
  /// (Flutter ≥ 3.47 / required for analyze --fatal-infos on 3.50+).
  final bool useMaterialUi;

  String get projectPath => outputDirectory;

  NormalizedName get normalizedName => NameConverter.parse(name);

  ChicoIntegrationsConfig get chicoConfig => ChicoIntegrationsConfig(
    ui: ChicoPackageToggle(enabled: enableChicoUi),
    kit: ChicoPackageToggle(enabled: enableChicoKit),
    services: ChicoPackageToggle(enabled: enableChicoServices),
  );
}
