import 'dart:io';

import 'package:path/path.dart' as p;

import '../../core/exceptions.dart';
import '../../fs/write_plan.dart';
import '../context.dart';
import '../feature/feature_layout.dart';
import '../result.dart';
import '../runner.dart';
import '../shared/generator_options.dart';
import '../shared/ui_imports.dart';

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
    final target =
        (context.extra['target'] as String?)?.trim().toLowerCase() ?? 'generic';
    if (target == 'feature') {
      final layout = FeatureLayout(
        architecture: context.config.project.architecture,
        name: context.targetName,
      );
      final entityPath = p.join(context.projectRoot, layout.entity);
      if (!File(entityPath).existsSync()) {
        throw InvalidUsageException(
          'Feature "${layout.snake}" was not found.',
          details:
              'Expected ${layout.entity}\n'
              'Generate the feature first.',
        );
      }
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

    if (target == 'feature' && kind == 'unit') {
      return _featureOrientedTests(context, project: project, snake: snake);
    }

    final relativePath = feature == null
        ? 'test/$target/${snake}_test.dart'
        : 'test/features/$feature/$target/${snake}_test.dart';

    final useMaterialUi = await UiImports.projectUsesMaterialUi(
      context.projectRoot,
    );
    final content = kind == 'widget'
        ? _widgetTest(
            pascal: pascal,
            snake: snake,
            project: project,
            target: target,
            useMaterialUi: useMaterialUi,
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

  /// Refreshes feature-oriented mapping/use-case stubs when a feature exists.
  Future<GenerationResult> _featureOrientedTests(
    GenerationContext context, {
    required String project,
    required String snake,
  }) async {
    final pascal = context.targetName.pascalCase;
    final writes = <PlannedFileWrite>[
      PlannedFileWrite(
        relativePath: 'test/features/$snake/${snake}_entity_test.dart',
        content:
            '''
import 'package:flutter_test/flutter_test.dart';
import 'package:$project/features/$snake/domain/entities/$snake.dart';

void main() {
  group('$pascal', () {
    test('constructs with required fields', () {
      final item = $pascal(id: '1');
      expect(item.id, '1');
    });
  });
}
''',
      ),
    ];

    final remotePath = p.join(
      context.projectRoot,
      'lib',
      'features',
      snake,
      'data',
      'datasources',
      '${snake}_remote_datasource.dart',
    );
    if (File(remotePath).existsSync()) {
      writes.add(
        PlannedFileWrite(
          relativePath: 'test/features/$snake/${snake}_mapping_test.dart',
          content:
              '''
import 'package:flutter_test/flutter_test.dart';
// Refresh with: regenerate the feature with --from-api / --spec
// Mapping coverage lives in ${snake}_remote_datasource.dart mapDto.

void main() {
  group('$pascal remote mapping', () {
    test('placeholder — regenerate feature to refresh mapping asserts', () {
      expect(true, isTrue);
    });
  });
}
''',
        ),
      );
    }

    return commitWrites(
      context: context,
      writes: writes,
      message: 'Feature-oriented unit tests for $pascal generated.',
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
    test('scaffold placeholder — replace with real asserts', () {
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
    required bool useMaterialUi,
  }) {
    final materialImport = UiImports.materialImport(
      useMaterialUi: useMaterialUi,
    );
    return '''
$materialImport
import 'package:flutter_test/flutter_test.dart';
// Scaffold test — import package:$project widget/page for $pascal.

void main() {
  testWidgets('$pascal builds', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: Text('$pascal')),
      ),
    );
    expect(find.text('$pascal'), findsOneWidget);
  });
}
''';
  }
}
