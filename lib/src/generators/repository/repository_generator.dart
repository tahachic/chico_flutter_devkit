import 'dart:io';

import 'package:path/path.dart' as p;

import '../../core/exceptions.dart';
import '../../fs/write_plan.dart';
import '../../naming/name_converter.dart';
import '../context.dart';
import '../feature/feature_layout.dart';
import '../result.dart';
import '../runner.dart';
import '../shared/generated_test_support.dart';
import '../shared/generator_options.dart';

/// Generates repository contract + implementation into an existing feature.
///
/// Standalone generation without entity/model/datasource prerequisites fails
/// with an actionable [InvalidUsageException] instead of emitting broken code.
final class RepositoryGenerator extends BaseGenerator {
  @override
  String get name => 'repository';

  @override
  String get description =>
      'Generate a repository into an existing feature (requires entity/model/datasources).';

  @override
  Future<void> validate(GenerationContext context) async {
    final plan = _plan(context);
    final missing = _missingPrerequisites(context.projectRoot, plan);
    if (missing.isEmpty) return;

    final featureHint = plan.featureLabel;
    throw InvalidUsageException(
      'Repository prerequisites are missing for "$featureHint".',
      details:
          'Missing:\n'
          '${missing.map((path) => '  - $path').join('\n')}\n\n'
          'Generate a feature first, then the repository:\n'
          '  devkit generate feature $featureHint\n'
          '  devkit generate repository $featureHint --feature $featureHint\n\n'
          'Or pass --feature <existing_feature> when the feature already exists.',
    );
  }

  @override
  Future<GenerationResult> generate(GenerationContext context) async {
    // validate() already ran via GeneratorRunner; re-check for safety.
    await validate(context);

    final plan = _plan(context);
    final namedLayout = plan.layout;
    final includeCrud = GeneratorOptions.flag(context, 'crud');
    final includePagination = GeneratorOptions.flag(context, 'pagination');
    final includeSearch = GeneratorOptions.flag(context, 'search');
    final includeRemote = GeneratorOptions.flag(
      context,
      'remote',
      defaultValue: true,
    );
    final includeLocal = GeneratorOptions.flag(context, 'local');
    final project = context.config.project.name;
    final generateTests = GeneratorOptions.wantsTests(context);
    final isFlutter = GeneratedTestSupport.isFlutterProject(
      context.projectRoot,
    );

    if (!includeRemote && !includeLocal) {
      throw const InvalidUsageException(
        'Repository requires at least one datasource.',
        details: 'Keep remote enabled (default) and/or pass --local.',
      );
    }

    final remoteExists = File(
      p.join(context.projectRoot, namedLayout.remoteDatasource),
    ).existsSync();
    final localExists = File(
      p.join(context.projectRoot, namedLayout.localDatasource),
    ).existsSync();

    if (includeRemote && !remoteExists) {
      throw InvalidUsageException(
        'Remote datasource is required but missing.',
        details:
            '${namedLayout.remoteDatasource}\n'
            'Generate the feature with remote enabled, or omit remote '
            'dependency by using --no-remote --local.',
      );
    }
    if (includeLocal && !localExists) {
      throw InvalidUsageException(
        'Local datasource is required but missing.',
        details: namedLayout.localDatasource,
      );
    }

    final pascal = namedLayout.pascal;
    final writes = <PlannedFileWrite>[
      PlannedFileWrite(
        relativePath: namedLayout.repositoryContract,
        content: _contract(
          pascal: pascal,
          entityImport: namedLayout.packageImport(project, namedLayout.entity),
          includeCrud: includeCrud,
          includePagination: includePagination,
          includeSearch: includeSearch,
        ),
      ),
      PlannedFileWrite(
        relativePath: namedLayout.repositoryImpl,
        content: _impl(
          layout: namedLayout,
          project: project,
          includeRemote: includeRemote && remoteExists,
          includeLocal: includeLocal && localExists,
          includeCrud: includeCrud,
          includePagination: includePagination,
          includeSearch: includeSearch,
        ),
      ),
    ];

    if (generateTests) {
      writes.add(
        PlannedFileWrite(
          relativePath:
              'test/features/${namedLayout.snake}/repositories/${namedLayout.snake}_repository_test.dart',
          content: _test(pascal: pascal, isFlutter: isFlutter),
        ),
      );
    }

    return commitWrites(
      context: context,
      writes: writes,
      message:
          'Repository $pascal generated into feature ${plan.featureLabel}.\n'
          'Scaffold only — wire datasources in the composition root.',
    );
  }

  _RepoPlan _plan(GenerationContext context) {
    final architecture = GeneratorOptions.architecture(context);
    final feature = GeneratorOptions.featureName(context);
    final subject = context.targetName;
    final namedLayout = feature == null
        ? FeatureLayout(architecture: architecture, name: subject)
        : FeatureLayout(
            architecture: architecture,
            name: NameConverter.parse(feature),
          );
    return _RepoPlan(
      layout: namedLayout,
      featureLabel: feature ?? subject.snakeCase,
    );
  }

  List<String> _missingPrerequisites(String projectRoot, _RepoPlan plan) {
    final required = <String>[plan.layout.entity, plan.layout.model];
    final missing = <String>[];
    for (final relative in required) {
      if (!File(p.join(projectRoot, relative)).existsSync()) {
        missing.add(relative);
      }
    }
    // At least one datasource must exist for a usable repository.
    final remote = File(p.join(projectRoot, plan.layout.remoteDatasource));
    final local = File(p.join(projectRoot, plan.layout.localDatasource));
    if (!remote.existsSync() && !local.existsSync()) {
      missing.add(
        '${plan.layout.remoteDatasource} (or ${plan.layout.localDatasource})',
      );
    }
    return missing;
  }

  String _contract({
    required String pascal,
    required String entityImport,
    required bool includeCrud,
    required bool includePagination,
    required bool includeSearch,
  }) {
    final methods = <String>[
      '  Future<List<$pascal>> fetchAll();',
      if (includePagination)
        '  Future<List<$pascal>> fetchPage({required int page, int pageSize = 20});',
      if (includeSearch) '  Future<List<$pascal>> search(String query);',
      if (includeCrud) ...[
        '  Future<$pascal> create($pascal item);',
        '  Future<$pascal> update($pascal item);',
        '  Future<void> delete(String id);',
      ],
    ];
    return '''
$entityImport

/// Generated by Chico Flutter DevKit — repository contract
abstract interface class ${pascal}Repository {
${methods.join('\n')}
}
''';
  }

  String _impl({
    required FeatureLayout layout,
    required String project,
    required bool includeRemote,
    required bool includeLocal,
    required bool includeCrud,
    required bool includePagination,
    required bool includeSearch,
  }) {
    final pascal = layout.pascal;
    final ctorParams = <String>[
      if (includeRemote) 'required this._remote,',
      if (includeLocal) 'required this._local,',
    ].join(' ');
    final fields = <String>[
      if (includeRemote) '  final ${pascal}RemoteDataSource _remote;',
      if (includeLocal) '  final ${pascal}LocalDataSource _local;',
    ].join('\n');

    final fetchAll = includeRemote
        ? '''
    final remote = await _remote.fetchAll();
    ${includeLocal ? 'await _local.saveAll(remote);' : ''}
    return remote.map((model) => model.toEntity()).toList(growable: false);'''
        : '''
    final local = await _local.fetchAll();
    return local.map((model) => model.toEntity()).toList(growable: false);''';

    final extras = StringBuffer();
    if (includePagination && includeRemote) {
      extras.writeln('''
  @override
  Future<List<$pascal>> fetchPage({required int page, int pageSize = 20}) async {
    final remote = await _remote.fetchPage(page: page, pageSize: pageSize);
    return remote.map((model) => model.toEntity()).toList(growable: false);
  }
''');
    }
    if (includeSearch && includeRemote) {
      extras.writeln('''
  @override
  Future<List<$pascal>> search(String query) async {
    final remote = await _remote.search(query);
    return remote.map((model) => model.toEntity()).toList(growable: false);
  }
''');
    }
    if (includeCrud && includeRemote) {
      extras.writeln('''
  @override
  Future<$pascal> create($pascal item) async {
    final model = await _remote.create(${pascal}Model.fromEntity(item));
    return model.toEntity();
  }

  @override
  Future<$pascal> update($pascal item) async {
    final model = await _remote.update(${pascal}Model.fromEntity(item));
    return model.toEntity();
  }

  @override
  Future<void> delete(String id) => _remote.delete(id);
''');
    }

    final imports = [
      layout.packageImport(project, layout.entity),
      layout.packageImport(project, layout.model),
      layout.packageImport(project, layout.repositoryContract),
      if (includeRemote) layout.packageImport(project, layout.remoteDatasource),
      if (includeLocal) layout.packageImport(project, layout.localDatasource),
    ].join('\n');

    return '''
$imports

/// Generated by Chico Flutter DevKit — repository implementation
///
/// Scaffold: inject datasources from your composition root.
class ${pascal}RepositoryImpl implements ${pascal}Repository {
  ${pascal}RepositoryImpl({$ctorParams});

$fields

  @override
  Future<List<$pascal>> fetchAll() async {
$fetchAll
  }

$extras}
''';
  }

  String _test({required String pascal, required bool isFlutter}) {
    final import = GeneratedTestSupport.unitTestImport(isFlutter: isFlutter);
    return '''
$import

void main() {
  test('${pascal}Repository contract name is stable', () {
    expect('${pascal}Repository', isNotEmpty);
  });
}
''';
  }
}

final class _RepoPlan {
  const _RepoPlan({required this.layout, required this.featureLabel});

  final FeatureLayout layout;
  final String featureLabel;
}
