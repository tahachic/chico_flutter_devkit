import '../core/exceptions.dart';

/// Describes one unsupported OpenAPI construct found during validation.
final class OpenApiSupportIssue {
  const OpenApiSupportIssue({
    required this.construct,
    required this.location,
    required this.reason,
    required this.suggestion,
  });

  final String construct;
  final String location;
  final String reason;
  final String suggestion;

  @override
  String toString() =>
      '[$construct] at $location\n'
      '  Reason: $reason\n'
      '  Next: $suggestion';
}

/// Fail-closed validation of OpenAPI constructs before IR/codegen.
///
/// Rejects constructs that would otherwise be silently ignored or
/// misrepresented (empty schemas, AuthType.none for OAuth2, etc.).
abstract final class OpenApiSupportValidator {
  /// Validates [root] and throws [InvalidUsageException] when unsupported
  /// constructs are present.
  static void validate(Map<String, Object?> root, {String? sourceName}) {
    final issues = <OpenApiSupportIssue>[];
    final prefix = sourceName == null || sourceName.isEmpty
        ? ''
        : '$sourceName › ';

    _validateComponents(root, issues);
    _validateRootSecurity(root, issues);
    _validatePaths(root, issues);

    if (issues.isEmpty) return;

    final buffer = StringBuffer()
      ..writeln(
        'OpenAPI document uses unsupported construct(s) '
        '(${issues.length}):',
      )
      ..writeln();
    for (final issue in issues) {
      buffer
        ..writeln('• Construct: ${issue.construct}')
        ..writeln('  Location: $prefix${issue.location}')
        ..writeln('  Reason: ${issue.reason}')
        ..writeln('  Suggested action: ${issue.suggestion}')
        ..writeln();
    }
    buffer.writeln(
      'DevKit generates only a documented OpenAPI 3.x subset. '
      'Remove or replace unsupported constructs, or see doc/OPENAPI.md.',
    );

    throw InvalidUsageException(
      'Unsupported OpenAPI constructs prevent safe client generation.',
      details: buffer.toString().trim(),
    );
  }

  static void _validateComponents(
    Map<String, Object?> root,
    List<OpenApiSupportIssue> issues,
  ) {
    final components = _asMap(root['components']);
    if (components == null) return;

    final schemas = _asMap(components['schemas']);
    if (schemas != null) {
      for (final entry in schemas.entries) {
        _validateSchemaNode(
          entry.value,
          location: 'components.schemas.${entry.key}',
          issues: issues,
        );
      }
    }

    final schemes = _asMap(components['securitySchemes']);
    if (schemes != null) {
      for (final entry in schemes.entries) {
        _validateSecurityScheme(
          name: entry.key,
          raw: entry.value,
          location: 'components.securitySchemes.${entry.key}',
          issues: issues,
          mustBeSupported: false,
        );
      }
    }
  }

  static void _validateRootSecurity(
    Map<String, Object?> root,
    List<OpenApiSupportIssue> issues,
  ) {
    final components = _asMap(root['components']);
    final schemes = _asMap(components?['securitySchemes']) ?? const {};
    _validateSecurityRequirements(
      root['security'],
      location: 'security',
      schemes: schemes,
      issues: issues,
    );
  }

  static void _validatePaths(
    Map<String, Object?> root,
    List<OpenApiSupportIssue> issues,
  ) {
    final paths = _asMap(root['paths']);
    if (paths == null) return;

    final components = _asMap(root['components']);
    final schemes = _asMap(components?['securitySchemes']) ?? const {};

    for (final pathEntry in paths.entries) {
      final pathItem = _asMap(pathEntry.value);
      if (pathItem == null) continue;
      final pathLoc = 'paths.${pathEntry.key}';

      _validateParameters(
        pathItem['parameters'],
        location: '$pathLoc.parameters',
        issues: issues,
      );

      for (final method in const [
        'get',
        'post',
        'put',
        'patch',
        'delete',
        'head',
        'options',
        'trace',
      ]) {
        final op = _asMap(pathItem[method]);
        if (op == null) continue;
        final opLoc = '$pathLoc.$method';

        if (method == 'head' || method == 'options' || method == 'trace') {
          issues.add(
            OpenApiSupportIssue(
              construct: 'http.$method',
              location: opLoc,
              reason:
                  'Only get/post/put/patch/delete operations are generated.',
              suggestion:
                  'Remove this operation from the spec or generate the client '
                  'from a filtered document.',
            ),
          );
        }

        _validateParameters(
          op['parameters'],
          location: '$opLoc.parameters',
          issues: issues,
        );
        _validateRequestBody(
          op['requestBody'],
          location: '$opLoc.requestBody',
          issues: issues,
        );
        _validateResponses(
          op['responses'],
          location: '$opLoc.responses',
          issues: issues,
        );
        _validateSecurityRequirements(
          op['security'],
          location: '$opLoc.security',
          schemes: schemes,
          issues: issues,
        );

        if (op.containsKey('callbacks')) {
          issues.add(
            OpenApiSupportIssue(
              construct: 'callbacks',
              location: '$opLoc.callbacks',
              reason: 'Callbacks are not modeled by DevKit.',
              suggestion: 'Remove callbacks from the operation.',
            ),
          );
        }
      }
    }

    if (root.containsKey('webhooks')) {
      issues.add(
        const OpenApiSupportIssue(
          construct: 'webhooks',
          location: 'webhooks',
          reason: 'Webhooks are not supported.',
          suggestion: 'Remove the webhooks section before generating.',
        ),
      );
    }
  }

  static void _validateParameters(
    Object? raw, {
    required String location,
    required List<OpenApiSupportIssue> issues,
  }) {
    if (raw is! List) return;
    for (var i = 0; i < raw.length; i++) {
      final map = _asMap(raw[i]);
      if (map == null) continue;
      final name = map['name']?.toString() ?? '#$i';
      final paramLoc = '$location[$i]($name)';
      final locationIn = map['in']?.toString();
      if (locationIn == 'cookie') {
        issues.add(
          OpenApiSupportIssue(
            construct: 'parameter.in=cookie',
            location: paramLoc,
            reason: 'Cookie parameters are not supported.',
            suggestion:
                'Move authentication/state to header or query parameters, '
                'or remove this parameter.',
          ),
        );
      }
      if (map.containsKey('schema')) {
        _validateSchemaNode(
          map['schema'],
          location: '$paramLoc.schema',
          issues: issues,
        );
      }
    }
  }

  static void _validateRequestBody(
    Object? raw, {
    required String location,
    required List<OpenApiSupportIssue> issues,
  }) {
    final map = _asMap(raw);
    if (map == null) return;
    final content = _asMap(map['content']);
    if (content == null || content.isEmpty) return;

    final hasJson = content.containsKey('application/json');
    if (!hasJson) {
      final mediaList = content.keys.join(', ');
      issues.add(
        OpenApiSupportIssue(
          construct: 'requestBody.content',
          location: location,
          reason:
              'Request body has no application/json content '
              '(found: $mediaList). Non-JSON bodies are unsupported and '
              'must not be silently dropped.',
          suggestion:
              'Add application/json content or remove the requestBody from '
              'the spec used for generation.',
        ),
      );
      // Still walk nested schemas in other media types for composition issues.
    }

    for (final entry in content.entries) {
      final media = entry.key;
      final mediaMap = _asMap(entry.value);
      if (mediaMap != null && mediaMap.containsKey('schema')) {
        _validateSchemaNode(
          mediaMap['schema'],
          location: '$location.content.$media.schema',
          issues: issues,
        );
      }
    }
  }

  static void _validateResponses(
    Object? raw, {
    required String location,
    required List<OpenApiSupportIssue> issues,
  }) {
    final responses = _asMap(raw);
    if (responses == null) return;
    for (final entry in responses.entries) {
      final response = _asMap(entry.value);
      if (response == null) continue;
      final content = _asMap(response['content']);
      if (content == null) continue;
      for (final mediaEntry in content.entries) {
        final mediaMap = _asMap(mediaEntry.value);
        if (mediaMap == null) continue;
        if (mediaMap.containsKey('schema')) {
          _validateSchemaNode(
            mediaMap['schema'],
            location: '$location.${entry.key}.content.${mediaEntry.key}.schema',
            issues: issues,
          );
        }
      }
    }
  }

  static void _validateSecurityRequirements(
    Object? raw, {
    required String location,
    required Map<String, Object?> schemes,
    required List<OpenApiSupportIssue> issues,
  }) {
    if (raw == null) return;
    if (raw is! List) return;

    // Empty security list means optional/no auth — allowed.
    if (raw.isEmpty) return;

    for (var i = 0; i < raw.length; i++) {
      final req = _asMap(raw[i]);
      if (req == null) continue;
      if (req.isEmpty) continue; // {} means no auth for this alternative

      for (final schemeName in req.keys) {
        final schemeLoc = '$location[$i].$schemeName';
        final schemeRaw = schemes[schemeName];
        if (schemeRaw == null) {
          issues.add(
            OpenApiSupportIssue(
              construct: 'security.$schemeName',
              location: schemeLoc,
              reason:
                  'Security requirement references unknown scheme '
                  '"$schemeName".',
              suggestion:
                  'Define the scheme under components.securitySchemes or '
                  'remove the requirement.',
            ),
          );
          continue;
        }
        _validateSecurityScheme(
          name: schemeName,
          raw: schemeRaw,
          location:
              'components.securitySchemes.$schemeName (required at $schemeLoc)',
          issues: issues,
          mustBeSupported: true,
        );
      }
    }
  }

  static void _validateSecurityScheme({
    required String name,
    required Object? raw,
    required String location,
    required List<OpenApiSupportIssue> issues,
    required bool mustBeSupported,
  }) {
    final map = _asMap(raw);
    if (map == null) {
      issues.add(
        OpenApiSupportIssue(
          construct: 'securityScheme',
          location: location,
          reason: 'Security scheme "$name" is not an object.',
          suggestion: 'Fix the scheme definition.',
        ),
      );
      return;
    }

    final support = classifySecurityScheme(map);
    if (support.supported) return;

    // Declared-but-unused unsupported schemes are still rejected so they
    // cannot be silently selected as the preferred client auth scheme.
    issues.add(
      OpenApiSupportIssue(
        construct: support.construct,
        location: location,
        reason: mustBeSupported
            ? 'This security requirement uses unsupported scheme '
                  '"$name" (${support.construct}). Treating it as '
                  'unauthenticated would be incorrect.'
            : 'Security scheme "$name" (${support.construct}) is not in the '
                  'supported subset and must not be silently ignored or '
                  'downgraded to AuthType.none.',
        suggestion: support.suggestion,
      ),
    );
  }

  /// Classifies a security scheme map.
  static ({bool supported, String construct, String suggestion})
  classifySecurityScheme(Map<String, Object?> map) {
    final type = map['type']?.toString() ?? '<missing>';
    switch (type) {
      case 'apiKey':
        final location = map['in']?.toString();
        if (location == 'cookie') {
          return (
            supported: false,
            construct: 'securityScheme.apiKey.in=cookie',
            suggestion: 'Use apiKey in header or query, which DevKit supports.',
          );
        }
        return (supported: true, construct: 'apiKey', suggestion: '');
      case 'http':
        final scheme = map['scheme']?.toString().toLowerCase() ?? '';
        if (scheme == 'bearer') {
          return (supported: true, construct: 'http.bearer', suggestion: '');
        }
        if (scheme == 'basic') {
          return (
            supported: false,
            construct: 'http.basic',
            suggestion:
                'HTTP Basic is not generated. Use HTTP bearer or apiKey, '
                'or handle Basic auth outside the generated client.',
          );
        }
        return (
          supported: false,
          construct: 'http.$scheme',
          suggestion:
              'Only HTTP bearer is supported for http security schemes.',
        );
      case 'oauth2':
        return (
          supported: false,
          construct: 'oauth2',
          suggestion:
              'OAuth2 is not generated. Remove the requirement, or wrap the '
              'generated client with your own OAuth2 token provider after '
              'simplifying the spec to bearer/apiKey.',
        );
      case 'openIdConnect':
        return (
          supported: false,
          construct: 'openIdConnect',
          suggestion:
              'OpenID Connect is not generated. Use bearer/apiKey in the '
              'spec used for codegen, or integrate OIDC outside DevKit.',
        );
      default:
        return (
          supported: false,
          construct: 'securityScheme.type=$type',
          suggestion:
              'Use type apiKey or http (bearer). Unknown schemes are rejected.',
        );
    }
  }

  static void _validateSchemaNode(
    Object? raw, {
    required String location,
    required List<OpenApiSupportIssue> issues,
  }) {
    final map = _asMap(raw);
    if (map == null) return;

    final ref = map[r'$ref']?.toString();
    if (ref != null) {
      if (!ref.startsWith('#/components/schemas/')) {
        issues.add(
          OpenApiSupportIssue(
            construct: '\$ref (remote/non-local)',
            location: location,
            reason: 'Only local #/components/schemas/… refs are supported.',
            suggestion: 'Inline the schema or copy it into components.schemas.',
          ),
        );
      }
      // Ref targets are validated when walking components.schemas.
      return;
    }

    for (final construct in const ['oneOf', 'anyOf', 'discriminator', 'not']) {
      if (map.containsKey(construct)) {
        issues.add(
          OpenApiSupportIssue(
            construct: construct,
            location: location,
            reason:
                'Schema composition/discriminator "$construct" is unsupported. '
                'Silent conversion to an empty object model is not allowed.',
            suggestion:
                'Replace with a concrete object/enum/\$ref/allOf subset, or '
                'split polymorphic types before generating.',
          ),
        );
      }
    }

    final properties = _asMap(map['properties']);
    if (properties != null) {
      for (final entry in properties.entries) {
        _validateSchemaNode(
          entry.value,
          location: '$location.properties.${entry.key}',
          issues: issues,
        );
      }
    }

    if (map.containsKey('items')) {
      _validateSchemaNode(
        map['items'],
        location: '$location.items',
        issues: issues,
      );
    }

    final allOf = map['allOf'];
    if (allOf is List) {
      for (var i = 0; i < allOf.length; i++) {
        _validateSchemaNode(
          allOf[i],
          location: '$location.allOf[$i]',
          issues: issues,
        );
      }
    }

    final additional = map['additionalProperties'];
    if (additional != null && additional is! bool) {
      _validateSchemaNode(
        additional,
        location: '$location.additionalProperties',
        issues: issues,
      );
    }
  }

  static Map<String, Object?>? _asMap(Object? value) {
    if (value is Map<String, Object?>) return value;
    if (value is Map) {
      return {
        for (final entry in value.entries) entry.key.toString(): entry.value,
      };
    }
    return null;
  }
}
