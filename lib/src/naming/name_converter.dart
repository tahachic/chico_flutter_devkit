import '../core/exceptions.dart';

/// Normalized identifier forms used by generators and templates.
final class NormalizedName {
  const NormalizedName({
    required this.raw,
    required this.snakeCase,
    required this.camelCase,
    required this.pascalCase,
    required this.kebabCase,
    required this.titleCase,
  });

  final String raw;
  final String snakeCase;
  final String camelCase;
  final String pascalCase;
  final String kebabCase;
  final String titleCase;

  /// Template variables derived from this name.
  Map<String, Object?> toTemplateVars({String prefix = ''}) {
    return {
      '${prefix}className': pascalCase,
      '${prefix}pascalCaseName': pascalCase,
      '${prefix}camelCaseName': camelCase,
      '${prefix}snakeCaseName': snakeCase,
      '${prefix}kebabCaseName': kebabCase,
      '${prefix}titleCaseName': titleCase,
    };
  }
}

/// Converts free-form names into consistent Dart identifier forms.
///
/// Accepts: `product_details`, `product-details`, `ProductDetails`,
/// `product details`, `productDetails`.
abstract final class NameConverter {
  static final RegExp _validSnake = RegExp(r'^[a-z][a-z0-9_]*$');
  static final RegExp _splitPattern = RegExp(
    r'[_\-\s]+|(?<=[a-z0-9])(?=[A-Z])|(?<=[A-Z])(?=[A-Z][a-z])',
  );
  static final RegExp _partPattern = RegExp(r'^[A-Za-z][A-Za-z0-9]*$');

  /// Parses [input] into all common casings.
  static NormalizedName parse(String input) {
    final raw = input.trim();
    if (raw.isEmpty) {
      throw const InvalidUsageException('Name must not be empty.');
    }

    final parts = _split(raw);
    if (parts.isEmpty) {
      throw InvalidUsageException(
        'Unable to parse name "$input".',
        details: 'Use letters, digits, underscores, hyphens, or spaces.',
      );
    }

    for (final part in parts) {
      if (!_partPattern.hasMatch(part)) {
        throw InvalidUsageException(
          'Invalid name segment "$part" in "$input".',
        );
      }
    }

    final lowerParts = parts.map((part) => part.toLowerCase()).toList();
    final snake = lowerParts.join('_');
    if (!_validSnake.hasMatch(snake)) {
      throw InvalidUsageException(
        'Derived snake_case "$snake" is not a valid Dart identifier base.',
      );
    }

    final pascal = lowerParts.map(_capitalize).join();
    final camel =
        '${lowerParts.first}${lowerParts.skip(1).map(_capitalize).join()}';
    final kebab = lowerParts.join('-');
    final title = lowerParts.map(_capitalize).join(' ');

    return NormalizedName(
      raw: raw,
      snakeCase: snake,
      camelCase: camel,
      pascalCase: pascal,
      kebabCase: kebab,
      titleCase: title,
    );
  }

  /// Validates a single path segment (file/dir name without separators).
  static void validatePathSegment(String segment) {
    if (segment.isEmpty ||
        segment == '.' ||
        segment == '..' ||
        segment.contains('/') ||
        segment.contains(r'\') ||
        segment.contains('\x00')) {
      throw InvalidUsageException('Invalid path segment "$segment".');
    }
  }

  static List<String> _split(String input) {
    return input
        .split(_splitPattern)
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
  }

  static String _capitalize(String value) {
    if (value.isEmpty) return value;
    return '${value[0].toUpperCase()}${value.substring(1).toLowerCase()}';
  }
}
