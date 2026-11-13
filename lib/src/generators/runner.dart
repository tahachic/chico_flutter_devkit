import '../config/config_service.dart';
import '../config/overrides.dart';
import '../fs/write_plan.dart';
import '../template/catalog.dart';
import 'context.dart';
import 'generator.dart';
import 'registry.dart';
import 'result.dart';

/// Orchestrates config resolution → validate → generate.
final class GeneratorRunner {
  GeneratorRunner({
    required this.registry,
    required this.configService,
    this.templateCatalog,
    this.contextFactory = const GenerationContextFactory(),
  });

  final GeneratorRegistry registry;
  final ConfigService configService;
  final TemplateCatalog? templateCatalog;
  final GenerationContextFactory contextFactory;

  Future<GenerationResult> run({
    required String projectRoot,
    required String generatorName,
    required String targetName,
    ConfigOverrides overrides = const ConfigOverrides(),
    bool dryRun = false,
    bool force = false,
    Map<String, Object?> extra = const {},
  }) async {
    final generator = registry.get(generatorName);
    final resolved = configService.resolve(
      projectRoot: projectRoot,
      overrides: overrides,
    );

    final context = contextFactory.create(
      resolved: resolved,
      name: targetName,
      dryRun: dryRun,
      force: force,
      extra: extra,
      templateCatalog: templateCatalog,
    );

    await generator.validate(context);
    return generator.generate(context);
  }
}

/// Optional base class that applies planned writes through [SafeFileSystem].
abstract class BaseGenerator implements Generator {
  Future<GenerationResult> commitWrites({
    required GenerationContext context,
    required List<PlannedFileWrite> writes,
    String? message,
  }) async {
    final result = await context.fileSystem.applyWrites(
      writes,
      dryRun: context.dryRun,
      force: context.force,
    );
    return GenerationResult(
      generatorName: name,
      writes: result,
      message: message,
    );
  }
}
