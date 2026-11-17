import 'dart:convert';

import 'package:yaml/yaml.dart';

import '../core/exceptions.dart';
import '../naming/name_converter.dart';
import 'models.dart';
import 'support_validator.dart';

/// Parses OpenAPI 3.0 / 3.1 YAML or JSON into a DevKit IR.
///
/// Supported subset:
/// - `info`, `servers`, `paths` (get/post/put/patch/delete)
/// - path/query/header parameters
/// - JSON and multipart/form-data request bodies; JSON responses
/// - `components.schemas` objects, enums, arrays, `$ref`, simple `allOf`
/// - apiKey / HTTP bearer / HTTP basic security schemes
///
/// Unsupported constructs (`oneOf`, `anyOf`, OAuth2, …) are rejected by
/// [OpenApiSupportValidator] before IR construction — never silently
/// downgraded to empty models or [OpenApiAuthType.none].
final class OpenApiParser {
  const OpenApiParser();

  OpenApiDocument parseString(String source, {String? sourceName}) {
    final trimmed = source.trimLeft();
    if (trimmed.isEmpty) {
      throw InvalidUsageException(
        'OpenAPI specification is empty.',
        details: sourceName,
      );
    }

    final Object? loaded;
    try {
      if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
        loaded = jsonDecode(source);
      } else {
        loaded = loadYaml(source);
      }
    } on YamlException catch (error) {
      throw InvalidUsageException(
        'OpenAPI specification is not valid YAML.',
        details: error.message,
      );
    } on FormatException catch (error) {
      throw InvalidUsageException(
        'OpenAPI specification is not valid JSON/YAML.',
        details: error.message,
      );
    }

    if (loaded is! Map) {
      throw const InvalidUsageException('OpenAPI root must be an object.');
    }

    return parseMap(_stringKeyed(loaded), sourceName: sourceName);
  }

  OpenApiDocument parseMap(Map<String, Object?> root, {String? sourceName}) {
    final version = root['openapi']?.toString() ?? '';
    if (!version.startsWith('3.')) {
      throw InvalidUsageException(
        'Only OpenAPI 3.x is supported.',
        details:
            'Found openapi: "${version.isEmpty ? '<missing>' : version}"'
            '${sourceName == null ? '' : ' in $sourceName'}',
      );
    }

    // Fail closed before any IR that could misrepresent the document.
    OpenApiSupportValidator.validate(root, sourceName: sourceName);

    final info = _asMap(root['info']) ?? const {};
    final title = info['title']?.toString().trim();
    if (title == null || title.isEmpty) {
      throw const InvalidUsageException('OpenAPI info.title is required.');
    }

    final servers = <String>[];
    final serversRaw = root['servers'];
    if (serversRaw is List) {
      for (final entry in serversRaw) {
        final map = _asMap(entry);
        final url = map?['url']?.toString();
        if (url != null && url.isNotEmpty) servers.add(url);
      }
    }

    final components = _asMap(root['components']) ?? const {};
    final schemasRaw = _asMap(components['schemas']) ?? const {};
    final schemas = <String, OpenApiSchema>{};
    for (final entry in schemasRaw.entries) {
      schemas[entry.key] = _parseNamedSchema(
        entry.key,
        entry.value,
        schemasRaw,
      );
    }

    final auth = _parseAuth(
      _asMap(components['securitySchemes']),
      root['security'],
    );

    final operations = <OpenApiOperation>[];
    final paths = _asMap(root['paths']) ?? const {};
    for (final pathEntry in paths.entries) {
      final path = pathEntry.key;
      final pathItem = _asMap(pathEntry.value);
      if (pathItem == null) continue;

      for (final method in OpenApiHttpMethod.values) {
        final opRaw = _asMap(pathItem[method.name]);
        if (opRaw == null) continue;
        operations.add(
          _parseOperation(
            path: path,
            method: method,
            operation: opRaw,
            schemasRaw: schemasRaw,
            usedIds: operations.map((o) => o.operationId).toSet(),
          ),
        );
      }
    }

    if (operations.isEmpty && schemas.isEmpty) {
      throw const InvalidUsageException(
        'OpenAPI specification has no paths or schemas to generate.',
      );
    }

    return OpenApiDocument(
      openApiVersion: version,
      title: title,
      version: info['version']?.toString() ?? '0.0.0',
      servers: servers,
      schemas: schemas,
      operations: operations,
      auth: auth,
    );
  }

  OpenApiSchema _parseNamedSchema(
    String name,
    Object? raw,
    Map<String, Object?> schemasRaw,
  ) {
    final map = _resolveSchemaMap(raw, schemasRaw);
    final description = map['description']?.toString();

    if (map['enum'] is List) {
      final values = (map['enum'] as List)
          .map((e) => e.toString())
          .toList(growable: false);
      return OpenApiSchema(
        name: name,
        kind: OpenApiSchemaKind.enumeration,
        enumValues: values,
        description: description,
      );
    }

    final type = map['type']?.toString();
    if (type == 'array') {
      final itemType = _dartTypeForSchema(
        map['items'],
        schemasRaw,
        nullable: false,
      );
      return OpenApiSchema(
        name: name,
        kind: OpenApiSchemaKind.alias,
        itemType: 'List<$itemType>',
        description: description,
      );
    }

    if (type != null && type != 'object' && map['properties'] == null) {
      final dartType = _primitiveDartType(type, map['format']?.toString());
      return OpenApiSchema(
        name: name,
        kind: OpenApiSchemaKind.alias,
        itemType: dartType,
        description: description,
      );
    }

    final properties = _asMap(map['properties']) ?? const {};
    final required = <String>{
      if (map['required'] is List)
        for (final item in map['required'] as List) item.toString(),
    };

    final fields = <OpenApiField>[];
    for (final prop in properties.entries) {
      final propMap = _resolveSchemaMap(prop.value, schemasRaw);
      final isRequired = required.contains(prop.key);
      final dartType = _dartTypeForSchema(
        prop.value,
        schemasRaw,
        nullable: !isRequired,
      );
      fields.add(
        OpenApiField(
          name: NameConverter.parse(prop.key).camelCase,
          dartType: dartType,
          jsonKey: prop.key,
          required: isRequired,
          description: propMap['description']?.toString(),
        ),
      );
    }

    return OpenApiSchema(
      name: name,
      kind: OpenApiSchemaKind.object,
      fields: fields,
      description: description,
    );
  }

  OpenApiOperation _parseOperation({
    required String path,
    required OpenApiHttpMethod method,
    required Map<String, Object?> operation,
    required Map<String, Object?> schemasRaw,
    required Set<String> usedIds,
  }) {
    final rawId = operation['operationId']?.toString().trim();
    final operationId = _uniqueId(
      rawId == null || rawId.isEmpty
          ? '${method.name}_${_pathToId(path)}'
          : rawId,
      usedIds,
    );
    final methodName = NameConverter.parse(operationId).camelCase;

    final parameters = <OpenApiParameter>[];
    final paramsRaw = operation['parameters'];
    if (paramsRaw is List) {
      for (final item in paramsRaw) {
        final map = _asMap(item);
        if (map == null) continue;
        final name = map['name']?.toString();
        if (name == null || name.isEmpty) continue;
        final location = switch (map['in']?.toString()) {
          'path' => OpenApiParameterLocation.path,
          'header' => OpenApiParameterLocation.header,
          _ => OpenApiParameterLocation.query,
        };
        final schema = map['schema'];
        final required =
            map['required'] == true ||
            location == OpenApiParameterLocation.path;
        parameters.add(
          OpenApiParameter(
            name: NameConverter.parse(name).camelCase,
            wireName: name,
            location: location,
            dartType: _dartTypeForSchema(
              schema,
              schemasRaw,
              nullable: !required,
            ),
            required: required,
            description: map['description']?.toString(),
          ),
        );
      }
    }

    String? requestBodyType;
    var requestEncoding = OpenApiRequestEncoding.none;
    var multipartParts = const <OpenApiMultipartPart>[];
    final requestBody = _asMap(operation['requestBody']);
    if (requestBody != null) {
      final content = _asMap(requestBody['content']);
      final json = _asMap(content?['application/json']);
      final multipart = _asMap(content?['multipart/form-data']);
      // Prefer JSON when both are present (common for dual content types).
      if (json != null) {
        requestEncoding = OpenApiRequestEncoding.json;
        requestBodyType = _dartTypeForSchema(
          json['schema'],
          schemasRaw,
          nullable: requestBody['required'] != true,
        );
      } else if (multipart != null) {
        requestEncoding = OpenApiRequestEncoding.multipart;
        multipartParts = _multipartParts(multipart['schema'], schemasRaw);
      }
    }

    String? successResponseType;
    final responses = _asMap(operation['responses']) ?? const {};
    for (final code in ['200', '201', '202', '204']) {
      final response = _asMap(responses[code]);
      if (response == null) continue;
      if (code == '204') {
        successResponseType = 'void';
        break;
      }
      final content = _asMap(response['content']);
      final json = _asMap(content?['application/json']);
      if (json != null) {
        successResponseType = _dartTypeForSchema(
          json['schema'],
          schemasRaw,
          nullable: false,
        );
        break;
      }
      successResponseType ??= 'void';
      break;
    }

    final paginated = parameters.any((p) {
      final lower = p.name.toLowerCase();
      return lower == 'page' ||
          lower == 'limit' ||
          lower == 'offset' ||
          lower == 'cursor' ||
          lower == 'perPage' ||
          lower == 'pageSize';
    });

    final tags = operation['tags'];
    final tag = tags is List && tags.isNotEmpty ? tags.first.toString() : null;

    return OpenApiOperation(
      operationId: operationId,
      method: method,
      path: path,
      methodName: methodName,
      summary:
          operation['summary']?.toString() ??
          operation['description']?.toString(),
      tag: tag,
      parameters: parameters,
      requestEncoding: requestEncoding,
      requestBodyType: requestBodyType,
      multipartParts: multipartParts,
      successResponseType: successResponseType ?? 'void',
      paginated: paginated,
    );
  }

  List<OpenApiMultipartPart> _multipartParts(
    Object? schemaRaw,
    Map<String, Object?> schemasRaw,
  ) {
    final resolved = _resolveSchemaMap(schemaRaw, schemasRaw);
    final properties = _asMap(resolved['properties']) ?? const {};
    final requiredKeys = <String>{
      if (resolved['required'] is List)
        ...(resolved['required'] as List).map((e) => e.toString()),
    };
    final parts = <OpenApiMultipartPart>[];
    for (final entry in properties.entries) {
      final propMap = _resolveSchemaMap(entry.value, schemasRaw);
      final format = propMap['format']?.toString();
      final isFile = format == 'binary' || format == 'byte';
      final required = requiredKeys.contains(entry.key);
      final dartType = isFile
          ? (required ? 'List<int>' : 'List<int>?')
          : _dartTypeForSchema(entry.value, schemasRaw, nullable: !required);
      parts.add(
        OpenApiMultipartPart(
          name: NameConverter.parse(entry.key).camelCase,
          wireName: entry.key,
          dartType: dartType,
          required: required,
          isFile: isFile,
        ),
      );
    }
    return parts;
  }

  OpenApiAuthConfig _parseAuth(
    Map<String, Object?>? schemes,
    Object? security,
  ) {
    // No schemes and no requirements → explicitly unauthenticated.
    if (schemes == null || schemes.isEmpty) {
      return const OpenApiAuthConfig();
    }

    // Prefer the first non-empty security requirement scheme name.
    String? preferred;
    if (security is List) {
      if (security.isEmpty) {
        // Explicit empty security array ⇒ optional/no auth.
        return const OpenApiAuthConfig();
      }
      for (final entry in security) {
        final map = _asMap(entry);
        if (map != null && map.isNotEmpty) {
          preferred = map.keys.first;
          break;
        }
      }
      // All alternatives were {} ⇒ no auth.
      if (preferred == null) {
        return const OpenApiAuthConfig();
      }
    } else {
      // No root security requirement: if schemes exist, use the first
      // *supported* scheme for client helpers (validator already rejected
      // unsupported schemes in components).
      preferred = schemes.keys.first;
    }

    final scheme = _asMap(schemes[preferred]);
    if (scheme == null) {
      throw InvalidUsageException(
        'Security scheme "$preferred" is missing.',
        details: 'components.securitySchemes.$preferred',
      );
    }

    final classified = OpenApiSupportValidator.classifySecurityScheme(scheme);
    if (!classified.supported) {
      throw InvalidUsageException(
        'Unsupported security scheme "$preferred" '
        '(${classified.construct}).',
        details:
            'Location: components.securitySchemes.$preferred\n'
            'Reason: unsupported schemes must not become AuthType.none.\n'
            'Suggested action: ${classified.suggestion}',
      );
    }

    final type = scheme['type']?.toString();
    if (type == 'apiKey') {
      final location = scheme['in']?.toString();
      final keyName = scheme['name']?.toString() ?? 'api_key';
      return OpenApiAuthConfig(
        type: OpenApiAuthType.apiKey,
        name: preferred,
        headerName: location == 'header' ? keyName : null,
        queryName: location == 'query' ? keyName : null,
      );
    }
    if (type == 'http') {
      final httpScheme = scheme['scheme']?.toString().toLowerCase();
      if (httpScheme == 'bearer') {
        return OpenApiAuthConfig(
          type: OpenApiAuthType.bearer,
          name: preferred,
          headerName: 'Authorization',
        );
      }
      if (httpScheme == 'basic') {
        return OpenApiAuthConfig(
          type: OpenApiAuthType.basic,
          name: preferred,
          headerName: 'Authorization',
        );
      }
    }

    // Defensive: classifier said supported but we cannot map it.
    throw InvalidUsageException(
      'Security scheme "$preferred" could not be mapped to generated auth.',
      details: 'components.securitySchemes.$preferred',
    );
  }

  Map<String, Object?> _resolveSchemaMap(
    Object? raw,
    Map<String, Object?> schemasRaw,
  ) {
    final map = _asMap(raw) ?? const <String, Object?>{};
    final ref = map[r'$ref']?.toString();
    if (ref != null) {
      final name = _refName(ref);
      final target = schemasRaw[name];
      if (target == null) {
        throw InvalidUsageException('Unresolved schema reference "$ref".');
      }
      return _resolveSchemaMap(target, schemasRaw);
    }

    final allOf = map['allOf'];
    if (allOf is List && allOf.isNotEmpty) {
      final merged = <String, Object?>{};
      final properties = <String, Object?>{};
      final required = <String>{};
      for (final part in allOf) {
        final partMap = _resolveSchemaMap(part, schemasRaw);
        merged.addAll(partMap);
        final props = _asMap(partMap['properties']);
        if (props != null) properties.addAll(props);
        if (partMap['required'] is List) {
          required.addAll(
            (partMap['required'] as List).map((e) => e.toString()),
          );
        }
      }
      merged['properties'] = properties;
      if (required.isNotEmpty) merged['required'] = required.toList();
      return merged;
    }

    return map;
  }

  String _dartTypeForSchema(
    Object? raw,
    Map<String, Object?> schemasRaw, {
    required bool nullable,
  }) {
    if (raw == null) {
      return nullable ? 'Object?' : 'Object';
    }

    final map = _asMap(raw) ?? const {};
    final ref = map[r'$ref']?.toString();
    if (ref != null) {
      final name = NameConverter.parse(_refName(ref)).pascalCase;
      return nullable ? '$name?' : name;
    }

    final allOf = map['allOf'];
    if (allOf is List && allOf.isNotEmpty) {
      for (final part in allOf) {
        final partMap = _asMap(part);
        final partRef = partMap?[r'$ref']?.toString();
        if (partRef != null) {
          final name = NameConverter.parse(_refName(partRef)).pascalCase;
          return nullable ? '$name?' : name;
        }
      }
    }

    if (map['enum'] is List) {
      // Inline enums fall back to String.
      return nullable ? 'String?' : 'String';
    }

    final type = map['type']?.toString() ?? 'object';
    if (type == 'array') {
      final item = _dartTypeForSchema(
        map['items'],
        schemasRaw,
        nullable: false,
      );
      return nullable ? 'List<$item>?' : 'List<$item>';
    }
    if (type == 'object') {
      if (map['additionalProperties'] != null && map['properties'] == null) {
        return nullable ? 'Map<String, dynamic>?' : 'Map<String, dynamic>';
      }
      return nullable ? 'Map<String, dynamic>?' : 'Map<String, dynamic>';
    }

    final primitive = _primitiveDartType(type, map['format']?.toString());
    return nullable ? '$primitive?' : primitive;
  }

  String _primitiveDartType(String type, String? format) {
    return switch (type) {
      'integer' => 'int',
      'number' => format == 'double' || format == 'float' ? 'double' : 'num',
      'boolean' => 'bool',
      'string' =>
        format == 'date-time' || format == 'date' ? 'DateTime' : 'String',
      _ => 'Object',
    };
  }

  String _refName(String ref) {
    const prefix = '#/components/schemas/';
    if (!ref.startsWith(prefix)) {
      throw InvalidUsageException(
        'Only local component schema refs are supported.',
        details: ref,
      );
    }
    return ref.substring(prefix.length);
  }

  String _pathToId(String path) {
    final cleaned = path
        .replaceAll(RegExp(r'[{}]'), '')
        .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');
    return cleaned.replaceAll(RegExp(r'^_+|_+$'), '');
  }

  String _uniqueId(String base, Set<String> used) {
    var candidate = base;
    var index = 2;
    while (used.contains(candidate)) {
      candidate = '${base}_$index';
      index++;
    }
    return candidate;
  }

  Map<String, Object?>? _asMap(Object? value) {
    if (value is YamlMap) return _stringKeyed(value);
    if (value is Map) return _stringKeyed(value);
    return null;
  }

  Map<String, Object?> _stringKeyed(Map<dynamic, dynamic> map) {
    return {for (final entry in map.entries) entry.key.toString(): entry.value};
  }
}
