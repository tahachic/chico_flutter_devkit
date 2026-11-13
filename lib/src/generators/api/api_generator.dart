import 'dart:io';

import 'package:path/path.dart' as p;

import '../../core/exceptions.dart';
import '../../fs/write_plan.dart';
import '../../naming/name_converter.dart';
import '../../openapi/models.dart';
import '../../openapi/parser.dart';
import '../context.dart';
import '../result.dart';
import '../runner.dart';
import 'api_codegen.dart';

/// Generates an isolated OpenAPI-backed Dart API client.
///
/// Usage: `devkit generate api shop --spec openapi.yaml`
final class ApiGenerator extends BaseGenerator {
  ApiGenerator({OpenApiParser parser = const OpenApiParser()})
    : _parser = parser;

  final OpenApiParser _parser;

  @override
  String get name => 'api';

  @override
  String get description =>
      'Generate a Dart API client from an OpenAPI 3.x specification.';

  @override
  Future<void> validate(GenerationContext context) async {
    final specPath = context.extra['spec'] as String?;
    if (specPath == null || specPath.trim().isEmpty) {
      throw const InvalidUsageException(
        'OpenAPI specification path is required.',
        details: 'Pass --spec path/to/openapi.yaml (or .json)',
      );
    }
    final file = File(
      p.isAbsolute(specPath) ? specPath : p.join(context.projectRoot, specPath),
    );
    if (!file.existsSync()) {
      throw InvalidUsageException(
        'OpenAPI specification not found.',
        details: file.path,
      );
    }
    // Parse early so validate fails before writes.
    _loadDocument(context, file);
  }

  @override
  Future<GenerationResult> generate(GenerationContext context) async {
    final specPath = context.extra['spec'] as String;
    final file = File(
      p.isAbsolute(specPath) ? specPath : p.join(context.projectRoot, specPath),
    );
    final document = _loadDocument(context, file);

    final clientPascal = _clientPascal(context);
    final clientSnake = context.targetName.snakeCase;
    final baseUrlOverride = context.extra['baseUrl'] as String?;
    final outputRoot =
        (context.extra['output'] as String?)?.trim().isNotEmpty == true
        ? (context.extra['output'] as String).trim()
        : 'lib/api/$clientSnake';

    final generatedRoot = '$outputRoot/generated';
    final effectiveDocument =
        baseUrlOverride == null || baseUrlOverride.trim().isEmpty
        ? document
        : OpenApiDocument(
            openApiVersion: document.openApiVersion,
            title: document.title,
            version: document.version,
            servers: [baseUrlOverride.trim(), ...document.servers],
            schemas: document.schemas,
            operations: document.operations,
            auth: document.auth,
          );

    final writes = <PlannedFileWrite>[
      PlannedFileWrite(
        relativePath: '$generatedRoot/exception.dart',
        content: ApiCodegen.exceptionFile(clientPascal),
      ),
      PlannedFileWrite(
        relativePath: '$generatedRoot/auth.dart',
        content: ApiCodegen.authFile(
          clientPascal: clientPascal,
          auth: effectiveDocument.auth,
        ),
      ),
      PlannedFileWrite(
        relativePath: '$generatedRoot/client.dart',
        content: ApiCodegen.clientFile(
          clientPascal: clientPascal,
          document: effectiveDocument,
        ),
      ),
      PlannedFileWrite(
        relativePath: '$outputRoot/README.md',
        content: ApiCodegen.readme(
          clientPascal: clientPascal,
          clientSnake: clientSnake,
          document: effectiveDocument,
        ),
      ),
    ];

    final modelSchemas = effectiveDocument.schemas.values.toList(
      growable: false,
    )..sort((a, b) => a.name.compareTo(b.name));
    final enumTypeNames = {
      for (final schema in modelSchemas)
        if (schema.kind == OpenApiSchemaKind.enumeration)
          NameConverter.parse(schema.name).pascalCase,
    };
    final knownModelNames = {
      for (final schema in modelSchemas)
        if (schema.kind != OpenApiSchemaKind.alias)
          NameConverter.parse(schema.name).pascalCase,
    };

    if (modelSchemas.isNotEmpty) {
      writes.add(
        PlannedFileWrite(
          relativePath: '$generatedRoot/models/models.dart',
          content: ApiCodegen.modelsBarrel(
            clientPascal: clientPascal,
            schemas: modelSchemas,
          ),
        ),
      );
      for (final schema in modelSchemas) {
        if (schema.kind == OpenApiSchemaKind.alias) continue;
        final snake = NameConverter.parse(schema.name).snakeCase;
        writes.add(
          PlannedFileWrite(
            relativePath: '$generatedRoot/models/$snake.dart',
            content: ApiCodegen.modelFile(
              schema,
              enumTypeNames: enumTypeNames,
              knownModelNames: knownModelNames,
            ),
          ),
        );
      }
    }

    return commitWrites(
      context: context,
      writes: writes,
      message:
          'API client $clientPascal generated from ${p.basename(file.path)} '
          '(${effectiveDocument.operations.length} operation(s), '
          '${modelSchemas.where((s) => s.kind != OpenApiSchemaKind.alias).length} model(s)).',
    );
  }

  OpenApiDocument _loadDocument(GenerationContext context, File file) {
    final cached = context.extra['_parsedOpenApi'];
    if (cached is OpenApiDocument) return cached;
    final source = file.readAsStringSync();
    return _parser.parseString(source, sourceName: file.path);
  }

  String _clientPascal(GenerationContext context) {
    final raw = context.targetName.pascalCase;
    if (raw.endsWith('Api') || raw.endsWith('Client')) return raw;
    return '${raw}Api';
  }
}
