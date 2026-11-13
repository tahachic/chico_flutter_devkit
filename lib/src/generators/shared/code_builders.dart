import 'field_spec.dart';

/// Deterministic Dart snippets shared by generators.
abstract final class CodeBuilders {
  static String constructorParams(List<FieldSpec> fields, {bool named = true}) {
    if (fields.isEmpty) return '';
    if (!named) {
      return fields.map((f) => 'this.${f.name}').join(', ');
    }
    final required = <String>[];
    final optional = <String>[];
    for (final field in fields) {
      if (field.isNullable) {
        optional.add('this.${field.name}');
      } else {
        required.add('required this.${field.name}');
      }
    }
    final parts = [...required, ...optional];
    return '{${parts.join(', ')}}';
  }

  static String fieldDeclarations(List<FieldSpec> fields) {
    return fields.map((f) => '  final ${f.dartType} ${f.name};').join('\n');
  }

  static String copyWithParams(List<FieldSpec> fields) {
    return fields.map((f) => '${f.type}? ${f.name}').join(', ');
  }

  static String copyWithBody(String className, List<FieldSpec> fields) {
    final args = fields
        .map((f) => '      ${f.name}: ${f.name} ?? this.${f.name},')
        .join('\n');
    return '''
  $className copyWith({
    ${copyWithParams(fields)},
  }) {
    return $className(
$args
    );
  }''';
  }

  static String equality(String className, List<FieldSpec> fields) {
    if (fields.isEmpty) {
      return '''
  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is $className;

  @override
  int get hashCode => runtimeType.hashCode;''';
    }
    final comparisons = fields
        .map((f) => '          other.${f.name} == ${f.name}')
        .join(' &&\n');
    final hashes = fields.map((f) => f.name).join(', ');
    return '''
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is $className &&
$comparisons;

  @override
  int get hashCode => Object.hash($hashes);''';
  }

  static String fromJson(String className, List<FieldSpec> fields) {
    final assigns = fields
        .map((f) {
          return '      ${f.name}: ${_fromJsonExpr(f)},';
        })
        .join('\n');
    return '''
  factory $className.fromJson(Map<String, dynamic> json) {
    return $className(
$assigns
    );
  }''';
  }

  static String toJson(List<FieldSpec> fields) {
    final entries = fields
        .map((f) {
          return "      '${f.jsonKey}': ${_toJsonExpr(f)},";
        })
        .join('\n');
    return '''
  Map<String, dynamic> toJson() {
    return {
$entries
    };
  }''';
  }

  static String _fromJsonExpr(FieldSpec field) {
    final key = field.jsonKey;
    final access = "json['$key']";
    if (field.type == 'DateTime') {
      if (field.isNullable) {
        return '$access == null ? null : DateTime.parse($access as String)';
      }
      return 'DateTime.parse($access as String)';
    }
    if (field.type.startsWith('List<')) {
      final inner = field.type.substring(5, field.type.length - 1);
      if (field.isNullable) {
        return '($access as List<dynamic>?)?.cast<$inner>()';
      }
      return '($access as List<dynamic>).cast<$inner>()';
    }
    if (field.type.startsWith('Map<')) {
      if (field.isNullable) {
        return '$access as Map<String, dynamic>?';
      }
      return '$access as Map<String, dynamic>';
    }
    if (field.isNullable) {
      return '$access as ${field.type}?';
    }
    return '$access as ${field.type}';
  }

  static String _toJsonExpr(FieldSpec field) {
    if (field.type == 'DateTime') {
      return field.isNullable
          ? '${field.name}?.toIso8601String()'
          : '${field.name}.toIso8601String()';
    }
    return field.name;
  }
}
