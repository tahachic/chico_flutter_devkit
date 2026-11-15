import '../../config/models.dart';
import '../../core/exceptions.dart';
import '../../fs/write_plan.dart';
import '../context.dart';
import '../result.dart';
import '../runner.dart';
import '../shared/chico_dependency_guard.dart';
import '../shared/code_builders.dart';
import '../shared/field_spec.dart';
import '../shared/ui_imports.dart';
import 'feature_layout.dart';

/// Generates a full feature slice for the selected architecture.
final class FeatureGenerator extends BaseGenerator {
  @override
  String get name => 'feature';

  @override
  String get description =>
      'Generate a feature scaffold (domain/data/presentation) for the project architecture.';

  @override
  Future<void> validate(GenerationContext context) async {
    final includeRemote = context.extra['remote'] != false;
    final includeLocal = context.extra['local'] == true;
    if (!includeRemote && !includeLocal) {
      throw const InvalidUsageException(
        'Feature requires at least one datasource.',
        details: 'Keep remote enabled (default) and/or pass --local.',
      );
    }
    await ChicoDependencyGuard.ensure(context: context);
  }

  @override
  Future<GenerationResult> generate(GenerationContext context) async {
    final architecture = _architecture(context);
    final state = context.config.flutter.stateManagement;
    final layout = FeatureLayout(
      architecture: architecture,
      name: context.targetName,
    );
    final fields = _fields(context);
    final includeRemote = context.extra['remote'] != false;
    final includeLocal = context.extra['local'] == true;
    final includeCrud = context.extra['crud'] == true;
    final includePagination = context.extra['pagination'] == true;
    final includeSearch = context.extra['search'] == true;
    final includeFilters = context.extra['filters'] == true;
    final generateTests = _wantsTests(context);
    final project = context.config.project.name;
    final useChico = UiImports.useChico(context.config);

    final writes = <PlannedFileWrite>[
      PlannedFileWrite(
        relativePath: layout.entity,
        content: _entity(layout, fields),
      ),
      PlannedFileWrite(
        relativePath: layout.model,
        content: _model(layout, fields, project: project),
      ),
      PlannedFileWrite(
        relativePath: layout.repositoryContract,
        content: _repositoryContract(
          layout,
          project: project,
          includeCrud: includeCrud,
          includePagination: includePagination,
          includeSearch: includeSearch,
        ),
      ),
      PlannedFileWrite(
        relativePath: layout.getUseCase,
        content: _getUseCase(layout, project: project),
      ),
      if (includeRemote)
        PlannedFileWrite(
          relativePath: layout.remoteDatasource,
          content: _remoteDatasource(
            layout,
            project: project,
            includeCrud: includeCrud,
            includePagination: includePagination,
            includeSearch: includeSearch,
          ),
        ),
      if (includeLocal)
        PlannedFileWrite(
          relativePath: layout.localDatasource,
          content: _localDatasource(layout, project: project),
        ),
      PlannedFileWrite(
        relativePath: layout.repositoryImpl,
        content: _repositoryImpl(
          layout,
          project: project,
          includeRemote: includeRemote,
          includeLocal: includeLocal,
          includeCrud: includeCrud,
          includePagination: includePagination,
          includeSearch: includeSearch,
        ),
      ),
      ..._stateFiles(layout, state, project: project),
      PlannedFileWrite(
        relativePath: layout.page,
        content: _page(
          layout,
          state: state,
          project: project,
          useChico: useChico,
          context: context,
          includeSearch: includeSearch,
          includeFilters: includeFilters,
          includePagination: includePagination,
        ),
      ),
      PlannedFileWrite(
        relativePath: layout.listTile,
        content: _listTile(layout, useChico: useChico, context: context),
      ),
    ];

    if (generateTests) {
      writes.add(
        PlannedFileWrite(
          relativePath:
              'test/features/${layout.snake}/${layout.snake}_entity_test.dart',
          content: _entityTest(layout, project: project, fields: fields),
        ),
      );
    }

    final flags = <String>[
      if (includeRemote) 'remote',
      if (includeLocal) 'local',
      if (includeCrud) 'crud',
      if (includePagination) 'pagination',
      if (includeSearch) 'search',
      if (includeFilters) 'filters',
    ].join(', ');

    final pending = _pendingImplementationCount(
      includeRemote: includeRemote,
      includeLocal: includeLocal,
      includeCrud: includeCrud,
    );
    final testCount = writes
        .where((write) => write.relativePath.startsWith('test/'))
        .length;

    return commitWrites(
      context: context,
      writes: writes,
      message:
          'Feature ${layout.pascal} scaffold generated '
          '(${architecture.yamlValue}/${state.yamlValue}'
          '${flags.isEmpty ? '' : '; $flags'}).\n'
          'Files planned: ${writes.length}\n'
          'Tests generated: $testCount\n'
          'Pending implementation: $pending method(s) in datasources/state\n'
          'This is a scaffold, not a complete connected CRUD implementation.',
    );
  }

  int _pendingImplementationCount({
    required bool includeRemote,
    required bool includeLocal,
    required bool includeCrud,
  }) {
    var count = 0;
    if (includeRemote) count += includeCrud ? 5 : 1; // fetch + optional CRUD
    if (includeLocal) count += 1;
    count += 1; // state load wiring
    return count;
  }

  Architecture _architecture(GenerationContext context) {
    final raw = context.extra['architecture'] as String?;
    if (raw != null && raw.isNotEmpty) {
      return Architecture.parse(raw);
    }
    return context.config.features.defaultArchitecture;
  }

  List<FieldSpec> _fields(GenerationContext context) {
    final fieldsRaw = context.extra['fields'] as String?;
    if (fieldsRaw != null && fieldsRaw.trim().isNotEmpty) {
      return FieldSpec.parseList(fieldsRaw);
    }
    return const [
      FieldSpec(name: 'id', type: 'String'),
      FieldSpec(name: 'name', type: 'String'),
      FieldSpec(name: 'description', type: 'String', isNullable: true),
    ];
  }

  bool _wantsTests(GenerationContext context) {
    final flag = context.extra['tests'];
    if (flag is bool) return flag;
    return context.config.features.generateTests;
  }

  String _entity(FeatureLayout layout, List<FieldSpec> fields) {
    return '''
/// Generated by Chico Flutter DevKit — feature entity:${layout.pascal}
class ${layout.pascal} {
  const ${layout.pascal}(${CodeBuilders.constructorParams(fields)});

${CodeBuilders.fieldDeclarations(fields)}

${CodeBuilders.copyWithBody(layout.pascal, fields)}

${CodeBuilders.equality(layout.pascal, fields)}
}
''';
  }

  String _model(
    FeatureLayout layout,
    List<FieldSpec> fields, {
    required String project,
  }) {
    return '''
${layout.packageImport(project, layout.entity)}

/// Generated by Chico Flutter DevKit — feature model:${layout.pascal}Model
class ${layout.pascal}Model {
  const ${layout.pascal}Model(${CodeBuilders.constructorParams(fields)});

${CodeBuilders.fieldDeclarations(fields)}

${CodeBuilders.fromJson('${layout.pascal}Model', fields)}

${CodeBuilders.toJson(fields)}

  ${layout.pascal} toEntity() {
    return ${layout.pascal}(
${fields.map((f) => '      ${f.name}: ${f.name},').join('\n')}
    );
  }

  factory ${layout.pascal}Model.fromEntity(${layout.pascal} entity) {
    return ${layout.pascal}Model(
${fields.map((f) => '      ${f.name}: entity.${f.name},').join('\n')}
    );
  }
}
''';
  }

  String _repositoryContract(
    FeatureLayout layout, {
    required String project,
    required bool includeCrud,
    required bool includePagination,
    required bool includeSearch,
  }) {
    final methods = <String>[
      '  Future<List<${layout.pascal}>> fetchAll();',
      if (includePagination)
        '  Future<List<${layout.pascal}>> fetchPage({required int page, int pageSize = 20});',
      if (includeSearch)
        '  Future<List<${layout.pascal}>> search(String query);',
      if (includeCrud) ...[
        '  Future<${layout.pascal}> create(${layout.pascal} item);',
        '  Future<${layout.pascal}> update(${layout.pascal} item);',
        '  Future<void> delete(String id);',
      ],
    ];
    return '''
${layout.packageImport(project, layout.entity)}

/// Generated by Chico Flutter DevKit — repository contract
abstract interface class ${layout.pascal}Repository {
${methods.join('\n')}
}
''';
  }

  String _getUseCase(FeatureLayout layout, {required String project}) {
    return '''
${layout.packageImport(project, layout.entity)}
${layout.packageImport(project, layout.repositoryContract)}

/// Generated by Chico Flutter DevKit — use case
class Get${layout.pascal}List {
  const Get${layout.pascal}List(this._repository);

  final ${layout.pascal}Repository _repository;

  Future<List<${layout.pascal}>> call() => _repository.fetchAll();
}
''';
  }

  String _remoteDatasource(
    FeatureLayout layout, {
    required String project,
    required bool includeCrud,
    required bool includePagination,
    required bool includeSearch,
  }) {
    final methods = <String>[
      '''
  Future<List<${layout.pascal}Model>> fetchAll() async {
    // TODO: replace with real API client call.
    return const <${layout.pascal}Model>[];
  }''',
      if (includePagination)
        '''
  Future<List<${layout.pascal}Model>> fetchPage({
    required int page,
    int pageSize = 20,
  }) async {
    return const <${layout.pascal}Model>[];
  }''',
      if (includeSearch)
        '''
  Future<List<${layout.pascal}Model>> search(String query) async {
    return const <${layout.pascal}Model>[];
  }''',
      if (includeCrud) ...[
        '''
  Future<${layout.pascal}Model> create(${layout.pascal}Model item) async => item;''',
        '''
  Future<${layout.pascal}Model> update(${layout.pascal}Model item) async => item;''',
        '''
  Future<void> delete(String id) async {}''',
      ],
    ];

    return '''
${layout.packageImport(project, layout.model)}

/// Generated by Chico Flutter DevKit — remote datasource
class ${layout.pascal}RemoteDataSource {
${methods.join('\n')}
}
''';
  }

  String _localDatasource(FeatureLayout layout, {required String project}) {
    return '''
${layout.packageImport(project, layout.model)}

/// Generated by Chico Flutter DevKit — local datasource
class ${layout.pascal}LocalDataSource {
  final List<${layout.pascal}Model> _cache = <${layout.pascal}Model>[];

  Future<List<${layout.pascal}Model>> fetchAll() async =>
      List<${layout.pascal}Model>.unmodifiable(_cache);

  Future<void> saveAll(List<${layout.pascal}Model> items) async {
    _cache
      ..clear()
      ..addAll(items);
  }
}
''';
  }

  String _repositoryImpl(
    FeatureLayout layout, {
    required String project,
    required bool includeRemote,
    required bool includeLocal,
    required bool includeCrud,
    required bool includePagination,
    required bool includeSearch,
  }) {
    final ctorParams = <String>[
      if (includeRemote) 'required this._remote,',
      if (includeLocal) 'required this._local,',
    ].join(' ');

    final fields = <String>[
      if (includeRemote) '  final ${layout.pascal}RemoteDataSource _remote;',
      if (includeLocal) '  final ${layout.pascal}LocalDataSource _local;',
    ].join('\n');

    final fetchAll = includeRemote && includeLocal
        ? '''
    final remote = await _remote.fetchAll();
    await _local.saveAll(remote);
    return remote.map((model) => model.toEntity()).toList(growable: false);'''
        : includeRemote
        ? '''
    final remote = await _remote.fetchAll();
    return remote.map((model) => model.toEntity()).toList(growable: false);'''
        : '''
    final local = await _local.fetchAll();
    return local.map((model) => model.toEntity()).toList(growable: false);''';

    final extras = StringBuffer();
    if (includePagination && includeRemote) {
      extras.writeln('''
  @override
  Future<List<${layout.pascal}>> fetchPage({
    required int page,
    int pageSize = 20,
  }) async {
    final remote = await _remote.fetchPage(page: page, pageSize: pageSize);
    return remote.map((model) => model.toEntity()).toList(growable: false);
  }
''');
    }
    if (includeSearch && includeRemote) {
      extras.writeln('''
  @override
  Future<List<${layout.pascal}>> search(String query) async {
    final remote = await _remote.search(query);
    return remote.map((model) => model.toEntity()).toList(growable: false);
  }
''');
    }
    if (includeCrud && includeRemote) {
      extras.writeln('''
  @override
  Future<${layout.pascal}> create(${layout.pascal} item) async {
    final model = await _remote.create(${layout.pascal}Model.fromEntity(item));
    return model.toEntity();
  }

  @override
  Future<${layout.pascal}> update(${layout.pascal} item) async {
    final model = await _remote.update(${layout.pascal}Model.fromEntity(item));
    return model.toEntity();
  }

  @override
  Future<void> delete(String id) => _remote.delete(id);
''');
    }

    final imports = [
      layout.packageImport(project, layout.entity),
      if (includeCrud && includeRemote)
        layout.packageImport(project, layout.model),
      layout.packageImport(project, layout.repositoryContract),
      if (includeRemote) layout.packageImport(project, layout.remoteDatasource),
      if (includeLocal) layout.packageImport(project, layout.localDatasource),
    ].join('\n');

    return '''
$imports

/// Generated by Chico Flutter DevKit — repository implementation
class ${layout.pascal}RepositoryImpl implements ${layout.pascal}Repository {
  ${layout.pascal}RepositoryImpl({$ctorParams});

$fields

  @override
  Future<List<${layout.pascal}>> fetchAll() async {
$fetchAll
  }

$extras}
''';
  }

  List<PlannedFileWrite> _stateFiles(
    FeatureLayout layout,
    StateManagement state, {
    required String project,
  }) {
    final dir = layout.stateDir(state);
    switch (state) {
      case StateManagement.bloc:
        return [
          PlannedFileWrite(
            relativePath: '$dir/${layout.snake}_event.dart',
            content:
                '''
/// Generated by Chico Flutter DevKit — bloc events
sealed class ${layout.pascal}Event {
  const ${layout.pascal}Event();
}

final class ${layout.pascal}Started extends ${layout.pascal}Event {
  const ${layout.pascal}Started();
}

final class ${layout.pascal}Refreshed extends ${layout.pascal}Event {
  const ${layout.pascal}Refreshed();
}
''',
          ),
          PlannedFileWrite(
            relativePath: '$dir/${layout.snake}_state.dart',
            content:
                '''
${layout.packageImport(project, layout.entity)}

/// Generated by Chico Flutter DevKit — bloc states
sealed class ${layout.pascal}State {
  const ${layout.pascal}State();
}

final class ${layout.pascal}Initial extends ${layout.pascal}State {
  const ${layout.pascal}Initial();
}

final class ${layout.pascal}Loading extends ${layout.pascal}State {
  const ${layout.pascal}Loading();
}

final class ${layout.pascal}Loaded extends ${layout.pascal}State {
  const ${layout.pascal}Loaded(this.items);

  final List<${layout.pascal}> items;
}

final class ${layout.pascal}Failure extends ${layout.pascal}State {
  const ${layout.pascal}Failure(this.message);

  final String message;
}
''',
          ),
          PlannedFileWrite(
            relativePath: '$dir/${layout.snake}_bloc.dart',
            content:
                '''
import 'package:flutter_bloc/flutter_bloc.dart';

${layout.packageImport(project, layout.getUseCase)}
import '${layout.snake}_event.dart';
import '${layout.snake}_state.dart';

/// Generated by Chico Flutter DevKit — bloc
class ${layout.pascal}Bloc extends Bloc<${layout.pascal}Event, ${layout.pascal}State> {
  ${layout.pascal}Bloc(this._getList) : super(const ${layout.pascal}Initial()) {
    on<${layout.pascal}Started>(_onStarted);
    on<${layout.pascal}Refreshed>(_onStarted);
  }

  final Get${layout.pascal}List _getList;

  Future<void> _onStarted(
    ${layout.pascal}Event event,
    Emitter<${layout.pascal}State> emit,
  ) async {
    emit(const ${layout.pascal}Loading());
    try {
      final items = await _getList();
      emit(${layout.pascal}Loaded(items));
    } catch (error) {
      emit(${layout.pascal}Failure(error.toString()));
    }
  }
}
''',
          ),
        ];
      case StateManagement.cubit:
        return [
          PlannedFileWrite(
            relativePath: '$dir/${layout.snake}_state.dart',
            content:
                '''
${layout.packageImport(project, layout.entity)}

/// Generated by Chico Flutter DevKit — cubit states
sealed class ${layout.pascal}State {
  const ${layout.pascal}State();
}

final class ${layout.pascal}Initial extends ${layout.pascal}State {
  const ${layout.pascal}Initial();
}

final class ${layout.pascal}Loading extends ${layout.pascal}State {
  const ${layout.pascal}Loading();
}

final class ${layout.pascal}Loaded extends ${layout.pascal}State {
  const ${layout.pascal}Loaded(this.items);

  final List<${layout.pascal}> items;
}

final class ${layout.pascal}Failure extends ${layout.pascal}State {
  const ${layout.pascal}Failure(this.message);

  final String message;
}
''',
          ),
          PlannedFileWrite(
            relativePath: '$dir/${layout.snake}_cubit.dart',
            content:
                '''
import 'package:flutter_bloc/flutter_bloc.dart';

${layout.packageImport(project, layout.getUseCase)}
import '${layout.snake}_state.dart';

/// Generated by Chico Flutter DevKit — cubit
class ${layout.pascal}Cubit extends Cubit<${layout.pascal}State> {
  ${layout.pascal}Cubit(this._getList) : super(const ${layout.pascal}Initial());

  final Get${layout.pascal}List _getList;

  Future<void> load() async {
    emit(const ${layout.pascal}Loading());
    try {
      final items = await _getList();
      emit(${layout.pascal}Loaded(items));
    } catch (error) {
      emit(${layout.pascal}Failure(error.toString()));
    }
  }
}
''',
          ),
        ];
      case StateManagement.riverpod:
        return [
          PlannedFileWrite(
            relativePath: '$dir/${layout.snake}_providers.dart',
            content:
                '''
import 'package:flutter_riverpod/flutter_riverpod.dart';

${layout.packageImport(project, layout.entity)}
${layout.packageImport(project, layout.getUseCase)}
${layout.packageImport(project, layout.repositoryContract)}

/// Generated by Chico Flutter DevKit — riverpod providers
final ${layout.snake}RepositoryProvider =
    Provider<${layout.pascal}Repository>((ref) {
  throw UnimplementedError(
    'Bind ${layout.pascal}Repository in the composition root.',
  );
});

final get${layout.pascal}ListProvider = Provider<Get${layout.pascal}List>((ref) {
  return Get${layout.pascal}List(ref.watch(${layout.snake}RepositoryProvider));
});

final ${layout.snake}ListProvider =
    FutureProvider<List<${layout.pascal}>>((ref) {
  return ref.watch(get${layout.pascal}ListProvider)();
});
''',
          ),
        ];
      case StateManagement.provider:
        return [
          PlannedFileWrite(
            relativePath: '$dir/${layout.snake}_provider.dart',
            content:
                '''
import 'package:flutter/foundation.dart';

${layout.packageImport(project, layout.entity)}
${layout.packageImport(project, layout.getUseCase)}

/// Generated by Chico Flutter DevKit — ChangeNotifier provider
class ${layout.pascal}Provider extends ChangeNotifier {
  ${layout.pascal}Provider(this._getList);

  final Get${layout.pascal}List _getList;

  bool loading = false;
  String? error;
  List<${layout.pascal}> items = const [];

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      items = await _getList();
    } catch (err) {
      error = err.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}
''',
          ),
        ];
    }
  }

  String _page(
    FeatureLayout layout, {
    required StateManagement state,
    required String project,
    required bool useChico,
    required GenerationContext context,
    required bool includeSearch,
    required bool includeFilters,
    required bool includePagination,
  }) {
    final hints = <String>[
      if (includeSearch) '// Search UI hook enabled.',
      if (includeFilters) '// Filters UI hook enabled.',
      if (includePagination) '// Pagination UI hook enabled.',
    ].map((line) => '    $line').join('\n');

    final stateHint = switch (state) {
      StateManagement.bloc =>
        '// TODO(devkit): wire BlocProvider<${layout.pascal}Bloc> + ${layout.pascal}ListTile.',
      StateManagement.cubit =>
        '// TODO(devkit): wire BlocProvider<${layout.pascal}Cubit> + ${layout.pascal}ListTile.',
      StateManagement.riverpod =>
        '// TODO(devkit): use ConsumerWidget + ${layout.pascal} providers/list tile.',
      StateManagement.provider =>
        '// TODO(devkit): wire ChangeNotifierProvider + ${layout.pascal}ListTile.',
    };

    if (useChico) {
      return '''
${UiImports.packageImport(context.config)}

/// Generated by Chico Flutter DevKit — page scaffold
class ${layout.pascal}Page extends StatelessWidget {
  const ${layout.pascal}Page({super.key});

  @override
  Widget build(BuildContext context) {
$hints
    $stateHint
    return ChicoScaffold(
      bar: const ChicoBar(title: '${layout.pascal}'),
      body: const ChicoPage(
        child: ChicoText(
          '${layout.pascal} page — connect ${state.yamlValue} state here.',
        ),
      ),
    );
  }
}
''';
    }

    return '''
import 'package:flutter/material.dart';

/// Generated by Chico Flutter DevKit — page scaffold
class ${layout.pascal}Page extends StatelessWidget {
  const ${layout.pascal}Page({super.key});

  @override
  Widget build(BuildContext context) {
$hints
    $stateHint
    return Scaffold(
      appBar: AppBar(title: const Text('${layout.pascal}')),
      body: const Center(
        child: Text(
          '${layout.pascal} page — connect ${state.yamlValue} state here.',        ),
      ),
    );
  }
}
''';
  }

  String _listTile(
    FeatureLayout layout, {
    required bool useChico,
    required GenerationContext context,
  }) {
    if (useChico) {
      return '''
${UiImports.packageImport(context.config)}

/// Generated by Chico Flutter DevKit — list tile
class ${layout.pascal}ListTile extends StatelessWidget {
  const ${layout.pascal}ListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.onPressed,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return ChicoListTile(
      title: title,
      subtitle: subtitle,
      onPressed: onPressed,
    );
  }
}
''';
    }

    return '''
import 'package:flutter/material.dart';

/// Generated by Chico Flutter DevKit — list tile
class ${layout.pascal}ListTile extends StatelessWidget {
  const ${layout.pascal}ListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      onTap: onTap,
    );
  }
}
''';
  }

  String _entityTest(
    FeatureLayout layout, {
    required String project,
    required List<FieldSpec> fields,
  }) {
    final args = fields
        .map((f) {
          if (f.type == 'String') {
            return f.isNullable
                ? '      ${f.name}: null,'
                : "      ${f.name}: '${f.name}',";
          }
          if (f.type == 'int') {
            return '      ${f.name}: ${f.isNullable ? 'null' : '1'},';
          }
          return '      ${f.name}: null,';
        })
        .join('\n');

    return '''
${layout.packageImport(project, layout.entity)}
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('${layout.pascal} equality', () {
    const a = ${layout.pascal}(
$args
    );
    const b = ${layout.pascal}(
$args
    );
    expect(a, b);
  });
}
''';
  }
}
