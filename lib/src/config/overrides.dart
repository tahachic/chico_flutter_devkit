import 'models.dart';

/// CLI / programmatic overrides applied on top of loaded configuration.
///
/// Overrides never mutate files; they only affect the in-memory resolved
/// configuration for the current command invocation.
final class ConfigOverrides {
  const ConfigOverrides({
    this.architecture,
    this.stateManagement,
    this.routing,
    this.dependencyInjection,
    this.overwrite,
    this.createBackups,
    this.generateTests,
    this.projectName,
    this.organization,
  });

  final Architecture? architecture;
  final StateManagement? stateManagement;
  final Routing? routing;
  final DependencyInjection? dependencyInjection;
  final bool? overwrite;
  final bool? createBackups;
  final bool? generateTests;
  final String? projectName;
  final String? organization;

  bool get isEmpty =>
      architecture == null &&
      stateManagement == null &&
      routing == null &&
      dependencyInjection == null &&
      overwrite == null &&
      createBackups == null &&
      generateTests == null &&
      projectName == null &&
      organization == null;

  DevKitConfig apply(DevKitConfig base) {
    if (isEmpty) return base;

    return base.copyWith(
      project: base.project.copyWith(
        name: projectName,
        architecture: architecture,
        organization: organization,
      ),
      flutter: base.flutter.copyWith(
        stateManagement: stateManagement,
        routing: routing,
        dependencyInjection: dependencyInjection,
      ),
      features: base.features.copyWith(
        defaultArchitecture: architecture,
        generateTests: generateTests,
      ),
      generation: base.generation.copyWith(
        overwrite: overwrite,
        createBackups: createBackups,
      ),
    );
  }
}
