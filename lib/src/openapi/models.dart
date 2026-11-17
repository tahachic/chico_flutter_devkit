/// Intermediate representation for a supported OpenAPI 3.x subset.
library;

enum OpenApiHttpMethod { get, post, put, patch, delete }

enum OpenApiParameterLocation { path, query, header }

enum OpenApiAuthType { none, apiKey, bearer, basic }

enum OpenApiRequestEncoding { none, json, multipart }

/// One part of a `multipart/form-data` request body.
final class OpenApiMultipartPart {
  const OpenApiMultipartPart({
    required this.name,
    required this.wireName,
    required this.dartType,
    required this.required,
    required this.isFile,
  });

  /// Dart identifier (camelCase).
  final String name;

  /// Form field name from the OpenAPI schema property key.
  final String wireName;
  final String dartType;
  final bool required;

  /// `true` when the property is `format: binary` / `byte` (file bytes).
  final bool isFile;
}

/// Top-level parsed document.
final class OpenApiDocument {
  const OpenApiDocument({
    required this.openApiVersion,
    required this.title,
    required this.version,
    required this.servers,
    required this.schemas,
    required this.operations,
    required this.auth,
  });

  final String openApiVersion;
  final String title;
  final String version;
  final List<String> servers;
  final Map<String, OpenApiSchema> schemas;
  final List<OpenApiOperation> operations;
  final OpenApiAuthConfig auth;

  String? get defaultServer => servers.isEmpty ? null : servers.first;
}

final class OpenApiAuthConfig {
  const OpenApiAuthConfig({
    this.type = OpenApiAuthType.none,
    this.name,
    this.headerName,
    this.queryName,
  });

  final OpenApiAuthType type;
  final String? name;
  final String? headerName;
  final String? queryName;
}

/// Resolved object / enum / alias schema used for Dart model generation.
final class OpenApiSchema {
  const OpenApiSchema({
    required this.name,
    required this.kind,
    this.fields = const [],
    this.enumValues = const [],
    this.itemType,
    this.description,
  });

  final String name;
  final OpenApiSchemaKind kind;
  final List<OpenApiField> fields;
  final List<String> enumValues;
  final String? itemType;
  final String? description;
}

enum OpenApiSchemaKind { object, enumeration, alias }

final class OpenApiField {
  const OpenApiField({
    required this.name,
    required this.dartType,
    required this.jsonKey,
    required this.required,
    this.description,
  });

  final String name;
  final String dartType;
  final String jsonKey;
  final bool required;
  final String? description;

  bool get isNullable => !required || dartType.endsWith('?');
}

final class OpenApiParameter {
  const OpenApiParameter({
    required this.name,
    required this.wireName,
    required this.location,
    required this.dartType,
    required this.required,
    this.description,
  });

  /// Dart identifier (camelCase).
  final String name;

  /// Original OpenAPI parameter name used in paths/query/headers.
  final String wireName;
  final OpenApiParameterLocation location;
  final String dartType;
  final bool required;
  final String? description;
}

final class OpenApiOperation {
  const OpenApiOperation({
    required this.operationId,
    required this.method,
    required this.path,
    required this.methodName,
    this.summary,
    this.tag,
    this.parameters = const [],
    this.requestEncoding = OpenApiRequestEncoding.none,
    this.requestBodyType,
    this.multipartParts = const [],
    this.successResponseType,
    this.paginated = false,
  });

  final String operationId;
  final OpenApiHttpMethod method;
  final String path;
  final String methodName;
  final String? summary;
  final String? tag;
  final List<OpenApiParameter> parameters;
  final OpenApiRequestEncoding requestEncoding;
  final String? requestBodyType;
  final List<OpenApiMultipartPart> multipartParts;
  final String? successResponseType;
  final bool paginated;
}
