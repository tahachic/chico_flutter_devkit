import 'dart:io';

import 'package:path/path.dart' as p;

import '../../core/exceptions.dart';
import '../../naming/name_converter.dart';
import '../../openapi/parser.dart';
import '../api/api_generator.dart';
import '../context.dart';
import '../shared/field_spec.dart';
import 'api_feature_wire.dart';

/// Orchestrates `generate feature --spec` (API client + wired feature).
abstract final class FeatureFromSpec {
  /// Fail-closed preflight: parse OpenAPI and validate list/field mapping.
  static void validate({
    required GenerationContext context,
    required List<FieldSpec> featureFields,
  }) {
    final specPath = (context.extra['spec'] as String?)?.trim();
    if (specPath == null || specPath.isEmpty) {
      throw const InvalidUsageException(
        'OpenAPI specification path is required for --spec.',
      );
    }
    final fromApi = (context.extra['fromApi'] as String?)?.trim();
    if (fromApi != null && fromApi.isNotEmpty) {
      throw const InvalidUsageException(
        'Use either --spec or --from-api, not both.',
        details:
            '--spec generates the API client then wires the feature.\n'
            '--from-api wires an already-generated client under lib/api/<name>.',
      );
    }
    if (context.extra['remote'] == false) {
      throw const InvalidUsageException(
        '--spec requires a remote datasource.',
        details: 'Omit --no-remote when generating from an OpenAPI spec.',
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

    final document = const OpenApiParser().parseString(
      file.readAsStringSync(),
      sourceName: file.path,
    );
    final apiName = apiClientName(context);
    ApiFeatureWire.validateFromDocument(
      document: document,
      apiName: apiName,
      featureSnake: context.targetName.snakeCase,
      featureFields: featureFields,
      needCrud: context.extra['crud'] == true,
      needPagination: context.extra['pagination'] == true,
      needSearch: context.extra['search'] == true,
      projectRoot: context.projectRoot,
    );
  }

  /// API client name: `--api-name` or the feature snake name.
  static String apiClientName(GenerationContext context) {
    final override = (context.extra['apiName'] as String?)?.trim();
    if (override != null && override.isNotEmpty) {
      return NameConverter.parse(override).snakeCase;
    }
    return context.targetName.snakeCase;
  }

  /// Writes the API client, then returns the client snake for `--from-api`.
  static Future<String> generateApiClient(GenerationContext context) async {
    final apiName = apiClientName(context);
    final apiContext = context.copyWith(
      targetName: NameConverter.parse(apiName),
      extra: {
        ...context.extra,
        'spec': context.extra['spec'],
        'baseUrl': context.extra['baseUrl'],
        'output': context.extra['output'],
      },
    );
    final api = ApiGenerator();
    await api.validate(apiContext);
    await api.generate(apiContext);
    return apiName;
  }
}
