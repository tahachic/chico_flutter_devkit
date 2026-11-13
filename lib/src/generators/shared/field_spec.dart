import '../../core/exceptions.dart';
import '../../naming/name_converter.dart';

/// One model / entity field.
final class FieldSpec {
  const FieldSpec({
    required this.name,
    required this.type,
    this.isNullable = false,
  });

  final String name;
  final String type;
  final bool isNullable;

  String get dartType => isNullable ? '$type?' : type;

  String get jsonKey => name;

  Map<String, Object?> toTemplateVars() => {
    'name': name,
    'type': type,
    'dartType': dartType,
    'isNullable': isNullable,
    'jsonKey': jsonKey,
  };

  /// Parses `id:String,name:String,price:double?,tags:List<String>` lists.
  static List<FieldSpec> parseList(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return const [];

    final fields = <FieldSpec>[];
    for (final part in trimmed.split(',')) {
      final piece = part.trim();
      if (piece.isEmpty) continue;
      final splitIndex = piece.indexOf(':');
      if (splitIndex <= 0) {
        throw InvalidUsageException(
          'Invalid field "$piece".',
          details: 'Expected name:Type, e.g. id:String,price:double?',
        );
      }
      final name = NameConverter.parse(
        piece.substring(0, splitIndex),
      ).camelCase;
      var typeRaw = piece.substring(splitIndex + 1).trim();
      var nullable = false;
      if (typeRaw.endsWith('?')) {
        nullable = true;
        typeRaw = typeRaw.substring(0, typeRaw.length - 1).trim();
      }
      if (typeRaw.isEmpty) {
        throw InvalidUsageException('Missing type for field "$name".');
      }
      fields.add(FieldSpec(name: name, type: typeRaw, isNullable: nullable));
    }
    return fields;
  }
}
