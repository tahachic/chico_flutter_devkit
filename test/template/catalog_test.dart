import 'dart:io';

import 'package:chico_flutter_devkit/chico_flutter_devkit.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test('loads fixture template and renders conditional files', () async {
    final root = p.normalize(p.join(Directory.current.path, 'templates'));
    final catalog = TemplateCatalog(rootDirectory: root);
    final descriptor = await catalog.loadDescriptor('_fixture');

    expect(descriptor.id, '_fixture');
    expect(descriptor.files, hasLength(2));

    final withTests = await catalog.renderAll(
      descriptor: descriptor,
      variables: {
        'className': 'Product',
        'snakeCaseName': 'product',
        'projectName': 'shop_app',
        'generateTests': true,
      },
    );
    expect(withTests.keys, contains('lib/generated/product.dart'));
    expect(withTests.keys, contains('test/generated/product_test.dart'));
    expect(withTests['lib/generated/product.dart'], contains('class Product'));

    final withoutTests = await catalog.renderAll(
      descriptor: descriptor,
      variables: {
        'className': 'Product',
        'snakeCaseName': 'product',
        'projectName': 'shop_app',
        'generateTests': false,
      },
    );
    expect(
      withoutTests.keys,
      isNot(contains('test/generated/product_test.dart')),
    );
  });
}
