import '../../config/models.dart';
import '../../naming/name_converter.dart';
import '../context.dart';
import '../feature/feature_layout.dart';

/// Shared option parsing for Phase 3/4 generators.
abstract final class GeneratorOptions {
  static Architecture architecture(GenerationContext context) {
    final raw = context.extra['architecture'] as String?;
    if (raw != null && raw.isNotEmpty) {
      return Architecture.parse(raw);
    }
    return context.config.features.defaultArchitecture;
  }

  static bool wantsTests(GenerationContext context) {
    final flag = context.extra['tests'];
    if (flag is bool) return flag;
    return context.config.features.generateTests;
  }

  static bool flag(
    GenerationContext context,
    String key, {
    bool defaultValue = false,
  }) {
    final value = context.extra[key];
    if (value is bool) return value;
    return defaultValue;
  }

  static String? featureName(GenerationContext context) {
    final raw = context.extra['feature'] as String?;
    if (raw == null || raw.trim().isEmpty) return null;
    return NameConverter.parse(raw).snakeCase;
  }

  static FeatureLayout? featureLayout(GenerationContext context) {
    final feature = featureName(context);
    if (feature == null) return null;
    return FeatureLayout(
      architecture: architecture(context),
      name: NameConverter.parse(feature),
    );
  }

  static List<String> values(GenerationContext context) {
    final raw = context.extra['values'] as String?;
    if (raw == null || raw.trim().isEmpty) return const [];
    return raw
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
  }
}
