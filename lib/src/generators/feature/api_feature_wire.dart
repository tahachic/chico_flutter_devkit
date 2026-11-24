import 'dart:io';

import 'package:path/path.dart' as p;

import '../../core/exceptions.dart';
import '../../naming/name_converter.dart';
import '../../openapi/models.dart';
import '../shared/field_spec.dart';

/// Resolves a generated OpenAPI client and plans feature remote wiring.
///
/// Fail-closed: missing client, no list operation, or unmappable required
/// feature fields throw [InvalidUsageException] before any feature writes.
abstract final class ApiFeatureWire {
  /// Pre-validate wiring against a parsed OpenAPI document (no disk client yet).
  static void validateFromDocument({
    required OpenApiDocument document,
    required String apiName,
    required String featureSnake,
    required List<FieldSpec> featureFields,
    required bool needCrud,
    required bool needPagination,
    required bool needSearch,
    required String projectRoot,
  }) {
    final methods = document.operations.map(_methodFromOperation).toList();
    final listMethod = _pickListMethod(methods, featureSnake: featureSnake);
    if (listMethod == null) {
      throw const InvalidUsageException(
        'No list operation found in the OpenAPI specification.',
        details:
            'Need a GET (or similar) operation returning an array of objects '
            '(e.g. listProducts → List<Product>).',
      );
    }
    final itemType = listMethod.listItemType!;
    final schema =
        document.schemas[itemType] ??
        document.schemas.values.cast<OpenApiSchema?>().firstWhere(
          (s) =>
              s != null && NameConverter.parse(s.name).pascalCase == itemType,
          orElse: () => null,
        );
    if (schema == null || schema.kind != OpenApiSchemaKind.object) {
      throw InvalidUsageException(
        'Could not resolve object schema for list item type $itemType.',
      );
    }
    final dtoFields = {
      for (final f in schema.fields)
        f.name: ApiDtoField(name: f.name, dartType: f.dartType),
    };
    _assertFieldMappings(
      featureFields: featureFields,
      dtoFields: dtoFields,
      itemType: itemType,
    );

    if (needCrud) {
      final createMethod = _pickCreateMethod(methods, itemType: itemType);
      final updateMethod = _pickUpdateMethod(methods, itemType: itemType);
      final deleteMethod = _pickDeleteMethod(methods);
      if (createMethod == null ||
          updateMethod == null ||
          deleteMethod == null) {
        throw InvalidUsageException(
          'OpenAPI spec is missing CRUD operations required by --crud.',
          details:
              'Need create, update/replace, and delete for $itemType.\n'
              'Found create=${createMethod?.name}, update=${updateMethod?.name}, '
              'delete=${deleteMethod?.name}.',
        );
      }
    }
    // needPagination / needSearch: local fallbacks allowed (same as resolve).
  }

  static ApiMethodInfo _methodFromOperation(OpenApiOperation op) {
    final returnType = op.successResponseType ?? 'void';
    String? listItem;
    final listMatch = RegExp(r'^List<(\w+)>$').firstMatch(returnType);
    if (listMatch != null) listItem = listMatch.group(1);
    final optionalParams = <String>[];
    final requiredParams = <String>[];
    for (final parameter in op.parameters) {
      if (parameter.required) {
        requiredParams.add(parameter.name);
      } else {
        optionalParams.add(parameter.name);
      }
    }
    if (op.requestBodyType != null) {
      requiredParams.add('body');
    }
    return ApiMethodInfo(
      name: op.methodName,
      returnType: returnType,
      listItemType: listItem,
      optionalParams: optionalParams,
      requiredParams: requiredParams,
      bodyType: op.requestBodyType,
    );
  }

  static void _assertFieldMappings({
    required List<FieldSpec> featureFields,
    required Map<String, ApiDtoField> dtoFields,
    required String itemType,
  }) {
    var mapped = 0;
    for (final field in featureFields) {
      final dto = dtoFields[field.name];
      if (dto == null) {
        if (field.isNullable) continue;
        throw InvalidUsageException(
          'Required feature field "${field.name}" is not on API model $itemType.',
          details:
              'API fields: ${dtoFields.keys.join(', ')}.\n'
              'Pass --fields that intersect the API model, or extend the OpenAPI schema.',
        );
      }
      final expr = _mapExpression(
        featureField: field,
        dtoFieldName: dto.name,
        dtoDartType: dto.dartType,
      );
      if (expr == null) {
        throw InvalidUsageException(
          'Cannot map API field ${dto.name} (${dto.dartType}) '
          'to feature field ${field.name} (${field.dartType}).',
        );
      }
      mapped++;
    }
    if (mapped == 0) {
      throw const InvalidUsageException(
        'No mappable fields between the feature and the API model.',
        details: 'At least one shared field name is required.',
      );
    }
  }

  /// Inspects `lib/api/<apiName>/generated/` and builds a wire plan.
  static ApiFeatureWirePlan resolve({
    required String projectRoot,
    required String apiName,
    required String featureSnake,
    required List<FieldSpec> featureFields,
    required bool needCrud,
    required bool needPagination,
    required bool needSearch,
  }) {
    final apiSnake = NameConverter.parse(apiName).snakeCase;
    final generatedRoot = p.join(
      projectRoot,
      'lib',
      'api',
      apiSnake,
      'generated',
    );
    final clientFile = File(p.join(generatedRoot, 'client.dart'));
    if (!clientFile.existsSync()) {
      throw InvalidUsageException(
        'API client "$apiSnake" was not found.',
        details:
            'Expected ${p.join('lib', 'api', apiSnake, 'generated', 'client.dart')}.\n'
            'Generate it first: devkit generate api $apiSnake --spec path/to/openapi.yaml',
      );
    }

    final clientSource = clientFile.readAsStringSync();
    final clientPascal = _clientClassName(clientSource);
    if (clientPascal == null) {
      throw InvalidUsageException(
        'Could not determine API client class in generated client.dart.',
        details: clientFile.path,
      );
    }

    final methods = _parseMethods(clientSource);
    final listMethod = _pickListMethod(methods, featureSnake: featureSnake);
    if (listMethod == null) {
      throw InvalidUsageException(
        'No list operation found on $clientPascal.',
        details:
            'Need a GET-style method returning Future<List<…>> '
            '(e.g. listProducts). Re-generate the API client from a spec that '
            'includes a collection endpoint.',
      );
    }

    final itemType = listMethod.listItemType!;
    final dtoFields = _readModelFields(generatedRoot, itemType);
    if (dtoFields.isEmpty) {
      throw InvalidUsageException(
        'Could not read fields for API model $itemType.',
        details: p.join(generatedRoot, 'models'),
      );
    }

    _assertFieldMappings(
      featureFields: featureFields,
      dtoFields: dtoFields,
      itemType: itemType,
    );
    final mappings = <ApiFieldMapping>[];
    for (final field in featureFields) {
      final dto = dtoFields[field.name];
      if (dto == null) {
        mappings.add(
          ApiFieldMapping(
            featureField: field,
            dtoFieldName: null,
            dtoDartType: null,
            expression: 'null',
          ),
        );
        continue;
      }
      mappings.add(
        ApiFieldMapping(
          featureField: field,
          dtoFieldName: dto.name,
          dtoDartType: dto.dartType,
          expression: _mapExpression(
            featureField: field,
            dtoFieldName: dto.name,
            dtoDartType: dto.dartType,
          )!,
        ),
      );
    }

    final hasPage = listMethod.optionalParams.contains('page');
    final hasQ = listMethod.optionalParams.contains('q');
    if (needPagination && !hasPage) {
      // Allowed: local slice after fetchAll (documented in generated source).
    }
    if (needSearch && !hasQ) {
      // Allowed: local filter after fetchAll.
    }

    ApiMethodInfo? createMethod;
    ApiMethodInfo? updateMethod;
    ApiMethodInfo? deleteMethod;
    String? inputType;

    if (needCrud) {
      createMethod = _pickCreateMethod(methods, itemType: itemType);
      updateMethod = _pickUpdateMethod(methods, itemType: itemType);
      deleteMethod = _pickDeleteMethod(methods);
      if (createMethod == null ||
          updateMethod == null ||
          deleteMethod == null) {
        throw InvalidUsageException(
          'API client $clientPascal is missing CRUD operations required by --crud.',
          details:
              'Need create (POST → $itemType), update/replace (PUT/PATCH → $itemType), '
              'and delete. Omit --crud or extend the OpenAPI spec.\n'
              'Found create=${createMethod?.name}, update=${updateMethod?.name}, '
              'delete=${deleteMethod?.name}.',
        );
      }
      inputType = createMethod.bodyType;
      if (inputType == null || inputType.isEmpty) {
        throw InvalidUsageException(
          'Create method ${createMethod.name} has no JSON body type.',
        );
      }
    }

    final packageImport =
        "import 'package:${_packageName(projectRoot)}/api/$apiSnake/generated/client.dart';";
    final modelsImport =
        "import 'package:${_packageName(projectRoot)}/api/$apiSnake/generated/models/models.dart';";

    return ApiFeatureWirePlan(
      apiSnake: apiSnake,
      clientPascal: clientPascal,
      clientImport: packageImport,
      modelsImport: modelsImport,
      listMethod: listMethod,
      itemType: itemType,
      mappings: mappings,
      listHasPage: hasPage,
      listHasQuery: hasQ,
      createMethod: createMethod,
      updateMethod: updateMethod,
      deleteMethod: deleteMethod,
      inputType: inputType,
      inputFields: inputType == null
          ? const {}
          : _readModelFields(generatedRoot, inputType),
    );
  }

  static String? _clientClassName(String source) {
    final match = RegExp(r'final class (\w+)\b').firstMatch(source);
    return match?.group(1);
  }

  static List<ApiMethodInfo> _parseMethods(String source) {
    final methods = <ApiMethodInfo>[];
    // Support Future<T> and Future<List<T>> (avoid [^>]+ truncating nested generics).
    final pattern = RegExp(
      r'Future<(List<\w+>|\w+)>\s+(\w+)\s*\(([^)]*)\)',
      multiLine: true,
    );
    for (final match in pattern.allMatches(source)) {
      final returnType = match.group(1)!.trim();
      final name = match.group(2)!;
      final paramsRaw = match.group(3) ?? '';
      final optionalParams = <String>[];
      final requiredParams = <String>[];
      String? bodyType;
      for (final part in paramsRaw.split(',')) {
        final piece = part.trim();
        if (piece.isEmpty) continue;
        final bodyMatch = RegExp(
          r'required\s+(\w+)\s+body\b',
        ).firstMatch(piece);
        if (bodyMatch != null) {
          bodyType = bodyMatch.group(1);
          requiredParams.add('body');
          continue;
        }
        final req = RegExp(r'required\s+\S+\s+(\w+)\b').firstMatch(piece);
        if (req != null) {
          requiredParams.add(req.group(1)!);
          continue;
        }
        final opt = RegExp(r'(\w+)\??\s+(\w+)\b').firstMatch(piece);
        if (opt != null) {
          optionalParams.add(opt.group(2)!);
        }
      }
      String? listItem;
      final listMatch = RegExp(r'^List<(\w+)>$').firstMatch(returnType);
      if (listMatch != null) {
        listItem = listMatch.group(1);
      }
      methods.add(
        ApiMethodInfo(
          name: name,
          returnType: returnType,
          listItemType: listItem,
          optionalParams: optionalParams,
          requiredParams: requiredParams,
          bodyType: bodyType,
        ),
      );
    }
    return methods;
  }

  static ApiMethodInfo? _pickListMethod(
    List<ApiMethodInfo> methods, {
    required String featureSnake,
  }) {
    final listMethods = methods
        .where((m) => m.listItemType != null)
        .toList(growable: false);
    if (listMethods.isEmpty) return null;

    final featurePascal = NameConverter.parse(featureSnake).pascalCase;
    final featureLower = featureSnake.toLowerCase().replaceAll('_', '');

    ApiMethodInfo? scoredBest;
    var bestScore = -1;
    for (final method in listMethods) {
      var score = 0;
      final nameLower = method.name.toLowerCase();
      if (nameLower.contains('list')) score += 10;
      if (nameLower.contains(featureLower)) score += 8;
      if (method.listItemType!.toLowerCase().contains(
        featurePascal.toLowerCase().replaceAll(RegExp(r's$'), ''),
      )) {
        score += 6;
      }
      if (nameLower.startsWith('get') && nameLower.contains('all')) score += 4;
      if (score > bestScore) {
        bestScore = score;
        scoredBest = method;
      }
    }
    return scoredBest ?? listMethods.first;
  }

  static ApiMethodInfo? _pickCreateMethod(
    List<ApiMethodInfo> methods, {
    required String itemType,
  }) {
    for (final method in methods) {
      final n = method.name.toLowerCase();
      if (method.bodyType != null &&
          method.returnType == itemType &&
          (n.contains('create') ||
              n.startsWith('add') ||
              n.startsWith('post'))) {
        return method;
      }
    }
    return null;
  }

  static ApiMethodInfo? _pickUpdateMethod(
    List<ApiMethodInfo> methods, {
    required String itemType,
  }) {
    for (final method in methods) {
      final n = method.name.toLowerCase();
      if (method.bodyType != null &&
          method.returnType == itemType &&
          (n.contains('update') ||
              n.contains('replace') ||
              n.contains('put') ||
              n.contains('patch'))) {
        return method;
      }
    }
    return null;
  }

  static ApiMethodInfo? _pickDeleteMethod(List<ApiMethodInfo> methods) {
    for (final method in methods) {
      final n = method.name.toLowerCase();
      if (n.contains('delete') || n.contains('remove')) {
        return method;
      }
    }
    return null;
  }

  static Map<String, ApiDtoField> _readModelFields(
    String generatedRoot,
    String typeName,
  ) {
    final snake = NameConverter.parse(typeName).snakeCase;
    final file = File(p.join(generatedRoot, 'models', '$snake.dart'));
    if (!file.existsSync()) return const {};
    final source = file.readAsStringSync();
    final fields = <String, ApiDtoField>{};
    for (final match in RegExp(
      r'final\s+([\w<>?]+)\s+(\w+);',
    ).allMatches(source)) {
      final dartType = match.group(1)!;
      final name = match.group(2)!;
      if (name.startsWith('_')) continue;
      fields[name] = ApiDtoField(name: name, dartType: dartType);
    }
    return fields;
  }

  static String? _mapExpression({
    required FieldSpec featureField,
    required String dtoFieldName,
    required String dtoDartType,
  }) {
    final target = featureField.type;
    final dto = dtoDartType.replaceAll('?', '');
    final access = 'dto.$dtoFieldName';

    if (target == 'String') {
      if (dto == 'String') return access;
      if (dto == 'int' || dto == 'num' || dto == 'double' || dto == 'bool') {
        return "'\$$access'";
      }
      // Enums and objects: toString
      return '$access.toString()';
    }
    if (target == 'int') {
      if (dto == 'int') return access;
      if (dto == 'num' || dto == 'double') return '$access.toInt()';
      if (dto == 'String') return 'int.parse($access)';
      return null;
    }
    if (target == 'double') {
      if (dto == 'double') return access;
      if (dto == 'num' || dto == 'int') return '$access.toDouble()';
      if (dto == 'String') return 'double.parse($access)';
      return null;
    }
    if (target == 'bool') {
      if (dto == 'bool') return access;
      return null;
    }
    if (target == dto) return access;
    return null;
  }

  static String _packageName(String projectRoot) {
    final pubspec = File(p.join(projectRoot, 'pubspec.yaml'));
    if (!pubspec.existsSync()) return 'app';
    final match = RegExp(
      r'^name:\s*(\S+)\s*$',
      multiLine: true,
    ).firstMatch(pubspec.readAsStringSync());
    return match?.group(1) ?? 'app';
  }
}

/// Planned wiring from a generated API client into a feature remote datasource.
final class ApiFeatureWirePlan {
  const ApiFeatureWirePlan({
    required this.apiSnake,
    required this.clientPascal,
    required this.clientImport,
    required this.modelsImport,
    required this.listMethod,
    required this.itemType,
    required this.mappings,
    required this.listHasPage,
    required this.listHasQuery,
    this.createMethod,
    this.updateMethod,
    this.deleteMethod,
    this.inputType,
    this.inputFields = const {},
  });

  final String apiSnake;
  final String clientPascal;
  final String clientImport;
  final String modelsImport;
  final ApiMethodInfo listMethod;
  final String itemType;
  final List<ApiFieldMapping> mappings;
  final bool listHasPage;
  final bool listHasQuery;
  final ApiMethodInfo? createMethod;
  final ApiMethodInfo? updateMethod;
  final ApiMethodInfo? deleteMethod;
  final String? inputType;
  final Map<String, ApiDtoField> inputFields;

  String get remoteConstructorParam => 'required this.api';

  String mapFromDtoExpression() {
    return mappings
        .map((m) {
          final name = m.featureField.name;
          if (m.dtoFieldName == null) {
            return '$name: null';
          }
          return '$name: ${m.expression}';
        })
        .join(',\n      ');
  }

  /// Builds `ProductInput(...)` args from a feature model instance named [itemVar].
  String mapToInputExpression(String itemVar) {
    if (inputType == null) return '';
    final featureNames = {
      for (final m in mappings) m.featureField.name: m.featureField,
    };
    final parts = <String>[];
    for (final entry in inputFields.entries) {
      final name = entry.key;
      final feature = featureNames[name];
      if (feature == null) continue;
      parts.add('$name: $itemVar.$name');
    }
    if (parts.isEmpty && featureNames.containsKey('name')) {
      parts.add('name: $itemVar.name');
    }
    return parts.join(',\n      ');
  }

  /// Path parameter name for update/delete (first required non-body param).
  String? get idPathParam {
    for (final method in [updateMethod, deleteMethod]) {
      if (method == null) continue;
      for (final param in method.requiredParams) {
        if (param != 'body') return param;
      }
    }
    return 'id';
  }
}

final class ApiFieldMapping {
  const ApiFieldMapping({
    required this.featureField,
    required this.dtoFieldName,
    required this.dtoDartType,
    required this.expression,
  });

  final FieldSpec featureField;
  final String? dtoFieldName;
  final String? dtoDartType;

  /// Dart expression using `dto` as the API model variable.
  final String expression;
}

final class ApiMethodInfo {
  const ApiMethodInfo({
    required this.name,
    required this.returnType,
    required this.listItemType,
    required this.optionalParams,
    required this.requiredParams,
    this.bodyType,
  });

  final String name;
  final String returnType;
  final String? listItemType;
  final List<String> optionalParams;
  final List<String> requiredParams;
  final String? bodyType;
}

final class ApiDtoField {
  const ApiDtoField({required this.name, required this.dartType});

  final String name;
  final String dartType;
}
