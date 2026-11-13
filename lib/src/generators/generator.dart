import 'context.dart';
import 'result.dart';

/// Contract for all DevKit generators.
///
/// Implementations must be independently testable and must not print.
abstract interface class Generator {
  /// CLI / registry name, e.g. `feature`, `model`.
  String get name;

  /// Short help text.
  String get description;

  /// Validates inputs before any filesystem mutation.
  Future<void> validate(GenerationContext context);

  /// Produces files (or a dry-run plan) for [context].
  Future<GenerationResult> generate(GenerationContext context);
}
