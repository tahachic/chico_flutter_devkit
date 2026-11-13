import 'dart:convert';

import '../../core/exceptions.dart';
import '../../naming/name_converter.dart';
import '../shared/field_spec.dart';

/// Infers [FieldSpec]s from a JSON object (map).
abstract final class JsonModelInferrer {
  static List<FieldSpec> fromJsonString(String source) {
    late final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException catch (error) {
      throw InvalidUsageException(
        'Invalid JSON input.',
        details: error.message,
        cause: error,
      );
    }
    return fromValue(decoded);
  }

  static List<FieldSpec> fromValue(Object? value) {
    if (value is List) {
      if (value.isEmpty) {
        throw const InvalidUsageException(
          'JSON array is empty; provide an object or a non-empty array.',
        );
      }
      return fromValue(value.first);
    }
    if (value is! Map) {
      throw const InvalidUsageException(
        'JSON root must be an object or an array of objects.',
      );
    }

    final fields = <FieldSpec>[];
    for (final entry in value.entries) {
      final key = entry.key.toString();
      final name = NameConverter.parse(key).camelCase;
      final inferred = _inferType(entry.value);
      fields.add(
        FieldSpec(
          name: name,
          type: inferred.type,
          isNullable: inferred.nullable || entry.value == null,
        ),
      );
    }
    if (fields.isEmpty) {
      throw const InvalidUsageException('JSON object has no fields.');
    }
    return fields;
  }

  static ({String type, bool nullable}) _inferType(Object? value) {
    if (value == null) return (type: 'Object', nullable: true);
    if (value is bool) return (type: 'bool', nullable: false);
    if (value is int) return (type: 'int', nullable: false);
    if (value is double) return (type: 'double', nullable: false);
    if (value is num) return (type: 'num', nullable: false);
    if (value is String) {
      if (_looksLikeDateTime(value)) {
        return (type: 'DateTime', nullable: false);
      }
      return (type: 'String', nullable: false);
    }
    if (value is List) {
      if (value.isEmpty) return (type: 'List<dynamic>', nullable: false);
      final inner = _inferType(value.first).type;
      return (type: 'List<$inner>', nullable: false);
    }
    if (value is Map) {
      return (type: 'Map<String, dynamic>', nullable: false);
    }
    return (type: 'Object', nullable: false);
  }

  static bool _looksLikeDateTime(String value) {
    return DateTime.tryParse(value) != null;
  }
}
