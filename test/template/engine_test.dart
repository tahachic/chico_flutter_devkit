import 'package:chico_flutter_devkit/chico_flutter_devkit.dart';
import 'package:test/test.dart';

void main() {
  const engine = TemplateEngine();

  test('interpolates variables', () {
    final out = engine.render('class {{className}} {}', {
      'className': 'Product',
    });
    expect(out, 'class Product {}');
  });

  test('supports if blocks', () {
    final withTests = engine.render('{{#if generateTests}}TEST{{/if}}', {
      'generateTests': true,
    });
    final withoutTests = engine.render('{{#if generateTests}}TEST{{/if}}', {
      'generateTests': false,
    });
    expect(withTests, 'TEST');
    expect(withoutTests, '');
  });

  test('supports unless blocks', () {
    final out = engine.render('{{#unless overwrite}}safe{{/unless}}', {
      'overwrite': false,
    });
    expect(out, 'safe');
  });

  test('supports each blocks', () {
    final out = engine.render('{{#each items}}- {{item}}\n{{/each}}', {
      'items': ['a', 'b'],
    });
    expect(out, '- a\n- b\n');
  });

  test('supports dotted lookup', () {
    final out = engine.render('{{project.name}}', {
      'project': {'name': 'shop_app'},
    });
    expect(out, 'shop_app');
  });

  test('fails on unclosed tags', () {
    expect(
      () => engine.render('Hello {{name', {'name': 'x'}),
      throwsA(isA<TemplateException>()),
    );
  });
}
