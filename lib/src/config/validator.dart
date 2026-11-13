import '../core/exceptions.dart';
import 'models.dart';

/// Validates semantic constraints on a parsed [DevKitConfig].
final class DevKitConfigValidator {
  const DevKitConfigValidator();

  void validate(DevKitConfig config) {
    final errors = <String>[];

    if (config.schemaVersion < 1) {
      errors.add('schemaVersion must be >= 1.');
    }

    if (!_isValidDartPackageName(config.project.name)) {
      errors.add(
        'project.name "${config.project.name}" is not a valid Dart package '
        'name (lowercase letters, digits, underscores; must start with a '
        'letter).',
      );
    }

    if (!_isValidOrganization(config.project.organization)) {
      errors.add(
        'project.organization "${config.project.organization}" must look like '
        'a reverse-DNS value (e.g. com.example).',
      );
    }

    if (config.codeStyle.lineLength < 40 || config.codeStyle.lineLength > 200) {
      errors.add('code_style.line_length must be between 40 and 200.');
    }

    if (config.flutter.localization.enabled &&
        config.flutter.localization.languages.isEmpty) {
      errors.add(
        'flutter.localization.languages must not be empty when localization '
        'is enabled.',
      );
    }

    for (final language in config.flutter.localization.languages) {
      if (!_isValidLanguageCode(language)) {
        errors.add(
          'Invalid language code "$language". Use short codes like en, fr, ar.',
        );
      }
    }

    _validatePackageVersion(
      errors,
      'chico.ui.version',
      config.chico.ui.version,
    );
    _validatePackageVersion(
      errors,
      'chico.kit.version',
      config.chico.kit.version,
    );
    _validatePackageVersion(
      errors,
      'chico.services.version',
      config.chico.services.version,
    );

    if (config.chico.services.enabled && !config.chico.kit.enabled) {
      errors.add(
        'chico.services requires chico.kit (services depends on kit). '
        'Enable kit or disable services.',
      );
    }

    if (config.chico.kit.enabled && !config.chico.ui.enabled) {
      errors.add(
        'chico.kit requires chico.ui (kit depends on / re-exports ui). '
        'Enable ui or disable kit.',
      );
    }

    if (errors.isNotEmpty) {
      throw ConfigException(
        'Configuration validation failed.',
        details: errors.map((e) => '- $e').join('\n'),
      );
    }
  }

  void _validatePackageVersion(
    List<String> errors,
    String field,
    String? version,
  ) {
    if (version == null || version.isEmpty) return;
    final pattern = RegExp(r'^[\^~>=<\s0-9A-Za-z\.\-\+]+$');
    if (!pattern.hasMatch(version)) {
      errors.add('$field "$version" is not a valid pub version constraint.');
    }
  }

  bool _isValidDartPackageName(String name) {
    return RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(name);
  }

  bool _isValidOrganization(String organization) {
    return RegExp(
      r'^[a-zA-Z][a-zA-Z0-9_]*(\.[a-zA-Z][a-zA-Z0-9_]*)+$',
    ).hasMatch(organization);
  }

  bool _isValidLanguageCode(String code) {
    return RegExp(r'^[a-z]{2}([_-][A-Za-z0-9]+)?$').hasMatch(code);
  }
}
