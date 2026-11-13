import 'dart:io';

import 'package:chico_flutter_devkit/src/openapi/models.dart';
import 'package:chico_flutter_devkit/src/openapi/parser.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  const parser = OpenApiParser();

  test('parses OpenAPI 3 YAML subset', () {
    final source = File(
      p.join('test', 'fixtures', 'openapi', 'shop_api.yaml'),
    ).readAsStringSync();
    final doc = parser.parseString(source);

    expect(doc.title, 'Shop API');
    expect(doc.defaultServer, 'https://api.shop.example.com/v1');
    expect(doc.auth.type, OpenApiAuthType.bearer);
    expect(
      doc.schemas.keys,
      containsAll(['Product', 'ProductInput', 'ProductStatus', 'Money']),
    );
    expect(doc.schemas['ProductStatus']!.kind, OpenApiSchemaKind.enumeration);
    expect(doc.operations.length, greaterThanOrEqualTo(6));
    expect(
      doc.operations.map((o) => o.method.name).toSet(),
      containsAll(['get', 'post', 'put', 'patch', 'delete']),
    );

    final list = doc.operations.firstWhere(
      (o) => o.operationId == 'listProducts',
    );
    expect(list.paginated, isTrue);
    expect(list.successResponseType, 'List<Product>');

    final get = doc.operations.firstWhere((o) => o.operationId == 'getProduct');
    expect(get.parameters.single.wireName, 'productId');
    expect(get.successResponseType, 'Product');

    final del = doc.operations.firstWhere(
      (o) => o.operationId == 'deleteProduct',
    );
    expect(del.successResponseType, 'void');
  });

  test('rejects non-3.x documents', () {
    expect(
      () => parser.parseString('{"swagger":"2.0","info":{"title":"x"}}'),
      throwsA(isA<Exception>()),
    );
  });
}
