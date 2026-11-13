import '../config/models.dart';

/// Describes a template package that generators can render.
final class TemplateDescriptor {
  const TemplateDescriptor({
    required this.id,
    required this.version,
    required this.description,
    required this.files,
    this.requiredVariables = const [],
    this.supportedArchitectures = const [],
    this.supportedStateManagement = const [],
  });

  final String id;
  final String version;
  final String description;

  /// Relative template file paths inside the template root.
  final List<TemplateFileSpec> files;

  final List<String> requiredVariables;
  final List<Architecture> supportedArchitectures;
  final List<StateManagement> supportedStateManagement;
}

/// One output file produced from a template source.
final class TemplateFileSpec {
  const TemplateFileSpec({
    required this.templatePath,
    required this.outputPath,
    this.condition,
  });

  /// Path of the template source relative to the template directory.
  final String templatePath;

  /// Output path template (may contain `{{snakeCaseName}}` etc.).
  final String outputPath;

  /// Optional variable name; file is skipped when falsy.
  final String? condition;
}
