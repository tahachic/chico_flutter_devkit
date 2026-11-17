import 'dart:io';

import 'package:chico_flutter_devkit/chico_flutter_devkit.dart';
import 'package:chico_flutter_devkit/src/openapi/models.dart';
import 'package:chico_flutter_devkit/src/openapi/parser.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  const parser = OpenApiParser();

  String fixture(String relative) =>
      File(p.join('test', 'fixtures', 'openapi', relative)).readAsStringSync();

  String fixturePath(String relative) =>
      p.absolute(p.join('test', 'fixtures', 'openapi', relative));

  group('unsupported constructs fail closed', () {
    final cases = <String, String>{
      'unsupported/oneof.yaml': 'oneOf',
      'unsupported/anyof.yaml': 'anyOf',
      'unsupported/discriminator.yaml': 'discriminator',
      'unsupported/oauth2.yaml': 'oauth2',
      'unsupported/openid.yaml': 'openIdConnect',
      'unsupported/unknown_security.yaml': 'securityScheme.type=mutualTLS',
      'unsupported/mixed_supported_unsupported.yaml': 'oneOf',
    };

    for (final entry in cases.entries) {
      test('${entry.key} rejects ${entry.value}', () {
        expect(
          () => parser.parseString(fixture(entry.key), sourceName: entry.key),
          throwsA(
            isA<InvalidUsageException>()
                .having(
                  (e) => e.message,
                  'message',
                  contains('Unsupported OpenAPI'),
                )
                .having((e) => e.details, 'details', contains(entry.value)),
          ),
        );
      });
    }

    test('unknown security requirement name is rejected', () {
      expect(
        () => parser.parseString('''
openapi: 3.0.3
info: {title: X, version: 1.0.0}
paths:
  /x:
    get:
      responses: {'200': {description: ok}}
security:
  - missingScheme: []
components:
  securitySchemes:
    bearerAuth:
      type: http
      scheme: bearer
'''),
        throwsA(
          isA<InvalidUsageException>().having(
            (e) => e.details,
            'details',
            contains('unknown scheme'),
          ),
        ),
      );
    });
  });

  group('supported auth / no-security', () {
    test('documents without security parse as AuthType.none', () {
      final doc = parser.parseString(fixture('supported/no_security.yaml'));
      expect(doc.auth.type, OpenApiAuthType.none);
      expect(doc.operations, isNotEmpty);
    });

    test('HTTP bearer remains supported', () {
      final doc = parser.parseString(fixture('shop_api.yaml'));
      expect(doc.auth.type, OpenApiAuthType.bearer);
    });

    test('API key remains supported', () {
      final doc = parser.parseString(fixture('supported/api_key.yaml'));
      expect(doc.auth.type, OpenApiAuthType.apiKey);
      expect(doc.auth.headerName, 'X-API-Key');
    });

    test('HTTP basic is supported', () {
      final doc = parser.parseString(fixture('supported/http_basic.yaml'));
      expect(doc.auth.type, OpenApiAuthType.basic);
      expect(doc.auth.headerName, 'Authorization');
    });

    test('multipart/form-data request bodies are supported', () {
      final doc = parser.parseString(fixture('supported/multipart.yaml'));
      expect(doc.operations, isNotEmpty);
      final op = doc.operations.first;
      expect(op.requestEncoding, OpenApiRequestEncoding.multipart);
      expect(op.multipartParts, hasLength(2));
      expect(op.multipartParts.where((p) => p.isFile).single.wireName, 'file');
      expect(
        op.multipartParts.where((p) => !p.isFile).single.wireName,
        'description',
      );
    });
  });

  group('api generator does not write on unsupported specs', () {
    late Directory tempRoot;
    late Directory homeDir;
    late ConfigService configService;
    late GeneratorRunner runner;

    setUp(() async {
      tempRoot = await Directory.systemTemp.createTemp('devkit_oa_fail_');
      homeDir = await Directory.systemTemp.createTemp('devkit_oa_fail_home_');
      configService = ConfigService(homeOverride: homeDir.path);
      await configService.initProjectConfig(
        projectRoot: tempRoot.path,
        config: DevKitConfigDefaults.create(projectName: 'shop_app'),
      );
      await File(p.join(tempRoot.path, 'pubspec.yaml')).writeAsString('''
name: shop_app
environment:
  sdk: ^3.8.0
''');
      // Preserve an existing user file outside generated/.
      await Directory(
        p.join(tempRoot.path, 'lib', 'api', 'shop'),
      ).create(recursive: true);
      await File(
        p.join(tempRoot.path, 'lib', 'api', 'shop', 'custom_wrapper.dart'),
      ).writeAsString('class KeepMe {}');

      runner = GeneratorRunner(
        registry: createDefaultGeneratorRegistry(),
        configService: configService,
      );
    });

    tearDown(() async {
      await tempRoot.delete(recursive: true);
      await homeDir.delete(recursive: true);
    });

    test('oauth2 generation fails and leaves tree untouched', () async {
      expect(
        () => runner.run(
          projectRoot: tempRoot.path,
          generatorName: 'api',
          targetName: 'shop',
          force: true,
          extra: {'spec': fixturePath('unsupported/oauth2.yaml')},
        ),
        throwsA(isA<InvalidUsageException>()),
      );

      expect(
        Directory(
          p.join(tempRoot.path, 'lib', 'api', 'shop', 'generated'),
        ).existsSync(),
        isFalse,
      );
      expect(
        File(
          p.join(tempRoot.path, 'lib', 'api', 'shop', 'custom_wrapper.dart'),
        ).readAsStringSync(),
        'class KeepMe {}',
      );
    });

    test('oneof generation fails without writing models', () async {
      expect(
        () => runner.run(
          projectRoot: tempRoot.path,
          generatorName: 'api',
          targetName: 'shop',
          force: true,
          extra: {'spec': fixturePath('unsupported/oneof.yaml')},
        ),
        throwsA(
          isA<InvalidUsageException>().having(
            (e) => e.details,
            'details',
            contains('oneOf'),
          ),
        ),
      );
      expect(
        Directory(
          p.join(tempRoot.path, 'lib', 'api', 'shop', 'generated'),
        ).existsSync(),
        isFalse,
      );
    });

    test('supported shop fixture still generates client files', () async {
      final result = await runner.run(
        projectRoot: tempRoot.path,
        generatorName: 'api',
        targetName: 'shop',
        force: true,
        extra: {'spec': fixturePath('shop_api.yaml')},
      );
      expect(result.writes.createdCount, greaterThan(3));
      expect(
        File(
          p.join(
            tempRoot.path,
            'lib',
            'api',
            'shop',
            'generated',
            'client.dart',
          ),
        ).existsSync(),
        isTrue,
      );
      expect(
        File(
          p.join(tempRoot.path, 'lib', 'api', 'shop', 'custom_wrapper.dart'),
        ).existsSync(),
        isTrue,
      );
    });
  });
}
