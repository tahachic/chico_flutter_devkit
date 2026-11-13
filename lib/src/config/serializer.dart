import 'models.dart';

/// Serializes [DevKitConfig] to YAML text.
final class DevKitConfigSerializer {
  const DevKitConfigSerializer();

  String toYaml(DevKitConfig config) {
    final buffer = StringBuffer()
      ..writeln('# Chico Flutter DevKit configuration')
      ..writeln('# Docs: doc/CONFIGURATION.md')
      ..writeln('schemaVersion: ${config.schemaVersion}')
      ..writeln()
      ..writeln('project:')
      ..writeln('  name: ${config.project.name}')
      ..writeln('  architecture: ${config.project.architecture.yamlValue}')
      ..writeln('  organization: ${config.project.organization}')
      ..writeln()
      ..writeln('flutter:')
      ..writeln(
        '  state_management: ${config.flutter.stateManagement.yamlValue}',
      )
      ..writeln('  routing: ${config.flutter.routing.yamlValue}')
      ..writeln(
        '  dependency_injection: '
        '${config.flutter.dependencyInjection.yamlValue}',
      )
      ..writeln('  localization:')
      ..writeln('    enabled: ${config.flutter.localization.enabled}')
      ..writeln('    languages:');
    for (final language in config.flutter.localization.languages) {
      buffer.writeln('      - $language');
    }

    buffer
      ..writeln()
      ..writeln('chico:')
      ..writeln('  ui:')
      ..writeln('    enabled: ${config.chico.ui.enabled}');
    if (config.chico.ui.version != null) {
      buffer.writeln('    version: "${config.chico.ui.version}"');
    }
    buffer
      ..writeln('  kit:')
      ..writeln('    enabled: ${config.chico.kit.enabled}');
    if (config.chico.kit.version != null) {
      buffer.writeln('    version: "${config.chico.kit.version}"');
    }
    buffer
      ..writeln('  services:')
      ..writeln('    enabled: ${config.chico.services.enabled}');
    if (config.chico.services.version != null) {
      buffer.writeln('    version: "${config.chico.services.version}"');
    }

    buffer
      ..writeln()
      ..writeln('features:')
      ..writeln(
        '  default_architecture: '
        '${config.features.defaultArchitecture.yamlValue}',
      )
      ..writeln('  generate_tests: ${config.features.generateTests}')
      ..writeln(
        '  generate_documentation: ${config.features.generateDocumentation}',
      )
      ..writeln()
      ..writeln('code_style:')
      ..writeln('  trailing_commas: ${config.codeStyle.trailingCommas}')
      ..writeln('  prefer_const: ${config.codeStyle.preferConst}')
      ..writeln('  line_length: ${config.codeStyle.lineLength}')
      ..writeln()
      ..writeln('generation:')
      ..writeln('  overwrite: ${config.generation.overwrite}')
      ..writeln('  create_backups: ${config.generation.createBackups}')
      ..writeln();

    return buffer.toString();
  }
}
