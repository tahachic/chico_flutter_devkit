import 'package:chico_flutter_devkit/chico_flutter_devkit.dart';
import 'package:test/test.dart';

void main() {
  group('NameConverter', () {
    test('parses snake_case', () {
      final name = NameConverter.parse('product_details');
      expect(name.snakeCase, 'product_details');
      expect(name.pascalCase, 'ProductDetails');
      expect(name.camelCase, 'productDetails');
      expect(name.kebabCase, 'product-details');
    });

    test('parses kebab-case', () {
      final name = NameConverter.parse('product-details');
      expect(name.pascalCase, 'ProductDetails');
      expect(name.snakeCase, 'product_details');
    });

    test('parses PascalCase', () {
      final name = NameConverter.parse('ProductDetails');
      expect(name.snakeCase, 'product_details');
      expect(name.camelCase, 'productDetails');
    });

    test('parses spaced names', () {
      final name = NameConverter.parse('Product Details');
      expect(name.snakeCase, 'product_details');
      expect(name.titleCase, 'Product Details');
    });

    test('rejects empty names', () {
      expect(
        () => NameConverter.parse('  '),
        throwsA(isA<InvalidUsageException>()),
      );
    });

    test('rejects invalid segments', () {
      expect(
        () => NameConverter.parse('123bad'),
        throwsA(isA<InvalidUsageException>()),
      );
    });

    test('template vars include className', () {
      final vars = NameConverter.parse('order_item').toTemplateVars();
      expect(vars['className'], 'OrderItem');
      expect(vars['snakeCaseName'], 'order_item');
    });
  });
}
