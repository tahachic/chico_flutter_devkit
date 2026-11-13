import '../core/exceptions.dart';

/// Lightweight template renderer for code generation.
///
/// Supported syntax:
/// - `{{name}}` / `{{{name}}}` — string interpolation (no HTML escaping)
/// - `{{#if name}}...{{/if}}` — include when truthy
/// - `{{#unless name}}...{{/unless}}` — include when falsy
/// - `{{#each items}}...{{/each}}` — iterate a list
final class TemplateEngine {
  const TemplateEngine();

  String render(String source, Map<String, Object?> variables) {
    try {
      return _render(source, variables);
    } on TemplateException {
      rethrow;
    } catch (error) {
      throw TemplateException(
        'Template rendering failed.',
        details: error.toString(),
        cause: error,
      );
    }
  }

  String _render(String source, Map<String, Object?> variables) {
    final buffer = StringBuffer();
    var index = 0;

    while (index < source.length) {
      final open = source.indexOf('{{', index);
      if (open < 0) {
        buffer.write(source.substring(index));
        break;
      }

      buffer.write(source.substring(index, open));

      if (open + 2 < source.length && source[open + 2] == '{') {
        final close = source.indexOf('}}}', open + 3);
        if (close < 0) {
          throw const TemplateException('Unclosed raw tag {{{ ... }}}');
        }
        final key = source.substring(open + 3, close).trim();
        buffer.write(_stringify(_lookup(variables, key)));
        index = close + 3;
        continue;
      }

      final close = source.indexOf('}}', open + 2);
      if (close < 0) {
        throw const TemplateException('Unclosed tag {{ ... }}');
      }

      final tag = source.substring(open + 2, close).trim();
      index = close + 2;

      if (tag.startsWith('#if ')) {
        final key = tag.substring(4).trim();
        final block = _readBlock(source, index, 'if');
        index = block.end;
        if (_isTruthy(_lookup(variables, key))) {
          buffer.write(_render(block.content, variables));
        }
        continue;
      }

      if (tag.startsWith('#unless ')) {
        final key = tag.substring(8).trim();
        final block = _readBlock(source, index, 'unless');
        index = block.end;
        if (!_isTruthy(_lookup(variables, key))) {
          buffer.write(_render(block.content, variables));
        }
        continue;
      }

      if (tag.startsWith('#each ')) {
        final key = tag.substring(6).trim();
        final block = _readBlock(source, index, 'each');
        index = block.end;
        final value = _lookup(variables, key);
        if (value is! Iterable) {
          throw TemplateException(
            'Expected "$key" to be a list for {{#each}}.',
          );
        }
        for (final item in value) {
          final scoped = Map<String, Object?>.from(variables);
          if (item is Map) {
            for (final entry in item.entries) {
              scoped[entry.key.toString()] = entry.value;
            }
          } else {
            scoped['item'] = item;
            scoped['.'] = item;
          }
          buffer.write(_render(block.content, scoped));
        }
        continue;
      }

      if (tag.startsWith('/') || tag.startsWith('#')) {
        throw TemplateException('Unexpected control tag "{{$tag}}".');
      }

      buffer.write(_stringify(_lookup(variables, tag)));
    }

    return buffer.toString();
  }

  _Block _readBlock(String source, int start, String name) {
    final openTag = '{{#$name';
    final closeTag = '{{/$name}}';
    var depth = 1;
    var index = start;

    while (index < source.length) {
      final nextOpen = source.indexOf(openTag, index);
      final nextClose = source.indexOf(closeTag, index);

      if (nextClose < 0) {
        throw TemplateException('Unclosed {{#$name}} block.');
      }

      if (nextOpen >= 0 && nextOpen < nextClose) {
        depth++;
        index = nextOpen + openTag.length;
        continue;
      }

      depth--;
      if (depth == 0) {
        return _Block(
          content: source.substring(start, nextClose),
          end: nextClose + closeTag.length,
        );
      }
      index = nextClose + closeTag.length;
    }

    throw TemplateException('Unclosed {{#$name}} block.');
  }

  Object? _lookup(Map<String, Object?> variables, String key) {
    if (variables.containsKey(key)) {
      return variables[key];
    }
    final parts = key.split('.');
    Object? current = variables;
    for (final part in parts) {
      if (current is Map) {
        current = current[part];
      } else {
        return null;
      }
    }
    return current;
  }

  bool _isTruthy(Object? value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is String) return value.isNotEmpty;
    if (value is Iterable) return value.isNotEmpty;
    if (value is num) return value != 0;
    return true;
  }

  String _stringify(Object? value) {
    if (value == null) return '';
    return value.toString();
  }
}

final class _Block {
  const _Block({required this.content, required this.end});

  final String content;
  final int end;
}
