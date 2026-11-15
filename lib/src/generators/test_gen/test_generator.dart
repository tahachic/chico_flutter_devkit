import '../../core/exceptions.dart';
import '../../fs/write_plan.dart';
import '../context.dart';
import '../result.dart';
import '../runner.dart';
import '../shared/generator_options.dart';

/// Generates unit or widget test scaffolding for a named target.
final class TestGenerator extends BaseGenerator {
  @override
  String get name => 'test';

  @override
  String get description =>
      'Generate unit/widget test scaffolding (--kind unit|widget).';

  @override
  Future<void> validate(GenerationContext context) async {
    final kind =
        (context.extra['kind'] as String?)?.trim().toLowerCase() ?? 'unit';
    if (kind != 'unit' && kind != 'widget') {
      throw InvalidUsageException(
        'Unknown test kind "$kind".',
        details: 'Expected: unit or widget',
      );
    }
  }

  @override
  Future<GenerationResult> generate(GenerationContext context) async {
    final kind =
        (context.extra['kind'] as String?)?.trim().toLowerCase() ?? 'unit';
    final target =
        (context.extra['target'] as String?)?.trim().toLowerCase() ?? 'generic';
    final feature = GeneratorOptions.featureName(context);
    final pascal = context.targetName.pascalCase;
    final snake = context.targetName.snakeCase;
    final project = context.config.project.name;

    final relativePath = feature == null
        ? 'test/$target/${snake}_test.dart'
        : 'test/features/$feature/$target/${snake}_test.dart';

    final content = kind == 'widget'
        ? _widgetTest(
            pascal: pascal,
            snake: snake,
            project: project,
            target: target,
          )
        : _unitTest(
            pascal: pascal,
            snake: snake,
            project: project,
            target: target,
          );

    return commitWrites(
      context: context,
      writes: [PlannedFileWrite(relativePath: relativePath, content: content)],
      message:
          '${kind[0].toUpperCase()}${kind.substring(1)} test for $pascal generated.',
    );
  }

  String _unitTest({
    required String pascal,
    required String snake,
    required String project,
    required String target,
  }) {
    final importHint = switch (target) {
      'model' => "import 'package:$project/models/$snake.dart';",
      'service' =>
        "import 'package:$project/services/${snake}_service_impl.dart';",
      _ => '// TODO: import the unit under test.',
    };

    return '''
$importHint
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('$pascal', () {
    test('placeholder assertion', () {
      expect(true, isTrue);
    });
  });
}
''';
  }

  String _widgetTest({
    required String pascal,
    required String snake,
    required String project,
    required String target,
  }) {
    return '''
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// TODO: import package:$project widget/page for $pascal.

void main() {
  testWidgets('$pascal builds', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Text('$pascal'),
        ),
      ),
    );
    expect(find.text('$pascal'), findsOneWidget);
  });
}
''';
  }
}
