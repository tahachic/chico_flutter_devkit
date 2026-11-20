import '../config/config_service.dart';
import '../config/models.dart';
import '../fs/safe_file_system.dart';
import '../naming/name_converter.dart';
import '../template/catalog.dart';
import '../template/engine.dart';

/// Shared runtime context passed to every generator.
final class GenerationContext {
  GenerationContext({
    required this.projectRoot,
    required this.config,
    required this.targetName,
    required this.fileSystem,
    required this.templateEngine,
    this.templateCatalog,
    this.dryRun = false,
    this.force = false,
    this.sync = false,
    this.extra = const {},
  });

  final String projectRoot;
  final DevKitConfig config;
  final NormalizedName targetName;
  final SafeFileSystem fileSystem;
  final TemplateEngine templateEngine;
  final TemplateCatalog? templateCatalog;
  final bool dryRun;
  final bool force;

  /// Refresh unchanged generated files recorded in the generate manifest.
  final bool sync;
  final Map<String, Object?> extra;

  /// Convenience: config + naming template variables.
  Map<String, Object?> get templateVariables {
    return {
      'projectName': config.project.name,
      'organization': config.project.organization,
      'architecture': config.project.architecture.yamlValue,
      'stateManagement': config.flutter.stateManagement.yamlValue,
      'generateTests': config.features.generateTests,
      'generateDocumentation': config.features.generateDocumentation,
      'overwrite': config.generation.overwrite || force,
      'createBackups': config.generation.createBackups,
      ...targetName.toTemplateVars(),
      ...extra,
    };
  }

  GenerationContext copyWith({
    String? projectRoot,
    DevKitConfig? config,
    NormalizedName? targetName,
    SafeFileSystem? fileSystem,
    TemplateEngine? templateEngine,
    TemplateCatalog? templateCatalog,
    bool? dryRun,
    bool? force,
    bool? sync,
    Map<String, Object?>? extra,
  }) {
    return GenerationContext(
      projectRoot: projectRoot ?? this.projectRoot,
      config: config ?? this.config,
      targetName: targetName ?? this.targetName,
      fileSystem: fileSystem ?? this.fileSystem,
      templateEngine: templateEngine ?? this.templateEngine,
      templateCatalog: templateCatalog ?? this.templateCatalog,
      dryRun: dryRun ?? this.dryRun,
      force: force ?? this.force,
      sync: sync ?? this.sync,
      extra: extra ?? this.extra,
    );
  }
}

/// Builds a [GenerationContext] from resolved configuration.
final class GenerationContextFactory {
  const GenerationContextFactory();

  GenerationContext create({
    required ResolvedConfig resolved,
    required String name,
    bool dryRun = false,
    bool force = false,
    bool sync = false,
    Map<String, Object?> extra = const {},
    TemplateCatalog? templateCatalog,
  }) {
    final fileSystem = SafeFileSystem(
      projectRoot: resolved.projectRoot,
      createBackups: resolved.config.generation.createBackups,
    );

    return GenerationContext(
      projectRoot: resolved.projectRoot,
      config: resolved.config,
      targetName: NameConverter.parse(name),
      fileSystem: fileSystem,
      templateEngine: const TemplateEngine(),
      templateCatalog: templateCatalog,
      dryRun: dryRun,
      force: force || resolved.config.generation.overwrite,
      sync: sync,
      extra: extra,
    );
  }
}
