import '../../config/models.dart';
import '../context.dart';
import '../result.dart';
import '../runner.dart';
import '../shared/generator_options.dart';
import '../shared/state_code.dart';

/// Generates Provider (ChangeNotifier) or Riverpod providers.
///
/// Use `--state riverpod` to emit Riverpod providers instead.
final class ProviderGenerator extends BaseGenerator {
  @override
  String get name => 'provider';

  @override
  String get description =>
      'Generate Provider/ChangeNotifier or Riverpod providers.';

  @override
  Future<void> validate(GenerationContext context) async {}

  @override
  Future<GenerationResult> generate(GenerationContext context) {
    final requested = context.extra['state'] as String?;
    final state = requested == null || requested.isEmpty
        ? (context.config.flutter.stateManagement == StateManagement.riverpod
              ? StateManagement.riverpod
              : StateManagement.provider)
        : StateManagement.parse(requested);

    final effective = state == StateManagement.riverpod
        ? StateManagement.riverpod
        : StateManagement.provider;

    final writes = StateCode.build(
      name: context.targetName,
      state: effective,
      project: context.config.project.name,
      architecture: GeneratorOptions.architecture(context),
      featureSnake: GeneratorOptions.featureName(context),
      generateTests: GeneratorOptions.wantsTests(context),
    );
    return commitWrites(
      context: context,
      writes: writes,
      message:
          '${effective == StateManagement.riverpod ? 'Riverpod' : 'Provider'} '
          '${context.targetName.pascalCase} generated.',
    );
  }
}
