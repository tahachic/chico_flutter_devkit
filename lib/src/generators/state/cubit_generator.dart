import '../../config/models.dart';
import '../context.dart';
import '../result.dart';
import '../runner.dart';
import '../shared/generator_options.dart';
import '../shared/state_code.dart';

/// Generates Cubit state/cubit files.
final class CubitGenerator extends BaseGenerator {
  @override
  String get name => 'cubit';

  @override
  String get description => 'Generate Cubit state and cubit class.';

  @override
  Future<void> validate(GenerationContext context) async {}

  @override
  Future<GenerationResult> generate(GenerationContext context) {
    final writes = StateCode.build(
      name: context.targetName,
      state: StateManagement.cubit,
      project: context.config.project.name,
      architecture: GeneratorOptions.architecture(context),
      featureSnake: GeneratorOptions.featureName(context),
      generateTests: GeneratorOptions.wantsTests(context),
    );
    return commitWrites(
      context: context,
      writes: writes,
      message: 'Cubit ${context.targetName.pascalCase} generated.',
    );
  }
}
