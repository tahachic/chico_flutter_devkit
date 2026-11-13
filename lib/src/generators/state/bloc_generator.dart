import '../../config/models.dart';
import '../context.dart';
import '../result.dart';
import '../runner.dart';
import '../shared/generator_options.dart';
import '../shared/state_code.dart';

/// Generates Bloc event/state/bloc files.
final class BlocGenerator extends BaseGenerator {
  @override
  String get name => 'bloc';

  @override
  String get description => 'Generate Bloc events, states, and bloc class.';

  @override
  Future<void> validate(GenerationContext context) async {}

  @override
  Future<GenerationResult> generate(GenerationContext context) {
    final writes = StateCode.build(
      name: context.targetName,
      state: StateManagement.bloc,
      project: context.config.project.name,
      architecture: GeneratorOptions.architecture(context),
      featureSnake: GeneratorOptions.featureName(context),
      generateTests: GeneratorOptions.wantsTests(context),
    );
    return commitWrites(
      context: context,
      writes: writes,
      message: 'Bloc ${context.targetName.pascalCase} generated.',
    );
  }
}
