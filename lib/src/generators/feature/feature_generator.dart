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
import 'feature_integration.dart';
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
            fields: fields,
            includeCrud: includeCrud,
            includePagination: includePagination,
            includeSearch: includeSearch,
          ),
        ),
      if (includeLocal)
        PlannedFileWrite(
          relativePath: layout.localDatasource,
          content: _localDatasource(layout, project: project, fields: fields),
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
      ..._stateFiles(
        layout,
        state,
        project: project,
        includeRemote: includeRemote,
        includeLocal: includeLocal,
      ),
      PlannedFileWrite(
        relativePath: layout.page,
        content: _page(
          layout,
          state: state,
          project: project,
          useChico: useChico,
          context: context,
          fields: fields,
          includeRemote: includeRemote,
          includeLocal: includeLocal,
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

    writes.addAll(
      FeatureIntegration.planHooks(
        context: context,
        layout: layout,
        includeRemote: includeRemote,
        includeLocal: includeLocal,
      ),
    );

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

    final testCount = writes
        .where((write) => write.relativePath.startsWith('test/'))
        .length;

    return commitWrites(
      context: context,
      writes: writes,
      message:
          'Feature ${layout.pascal} generated with demo in-memory data '
          '(${architecture.yamlValue}/${state.yamlValue}'
          '${flags.isEmpty ? '' : '; $flags'}).\n'
          'Files planned: ${writes.length}\n'
          'Tests generated: $testCount\n'
          'Open /features/${layout.snake} from Home (seeded list).\n'
          'Swap the datasource for a real API when you are ready.',
    );
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

  String _seedModels(FeatureLayout layout, List<FieldSpec> fields) {
    String row(int index) {
      final args = fields
          .map((f) => '      ${f.name}: ${f.sampleLiteral(index)},')
          .join('\n');
      return '    ${layout.pascal}Model(\n$args\n    ),';
    }

    return '${row(1)}\n${row(2)}\n${row(3)}';
  }

  String _remoteDatasource(
    FeatureLayout layout, {
    required String project,
    required List<FieldSpec> fields,
    required bool includeCrud,
    required bool includePagination,
    required bool includeSearch,
  }) {
    final seeds = _seedModels(layout, fields);
    final methods = <String>[
      '''
  Future<List<${layout.pascal}Model>> fetchAll() async {
    // Demo in-memory data — replace with your API client when ready.
    return List<${layout.pascal}Model>.unmodifiable(_items);
  }''',
      if (includePagination)
        '''
  Future<List<${layout.pascal}Model>> fetchPage({
    required int page,
    int pageSize = 20,
  }) async {
    final start = (page < 1 ? 0 : page - 1) * pageSize;
    if (start >= _items.length) {
      return const <${layout.pascal}Model>[];
    }
    final end = (start + pageSize).clamp(0, _items.length);
    return _items.sublist(start, end);
  }''',
      if (includeSearch)
        '''
  Future<List<${layout.pascal}Model>> search(String query) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return fetchAll();
    return _items
        .where((item) => item.toString().toLowerCase().contains(q))
        .toList(growable: false);
  }''',
      if (includeCrud) ...[
        '''
  Future<${layout.pascal}Model> create(${layout.pascal}Model item) async {
    _items.add(item);
    return item;
  }''',
        fields.any((f) => f.name == 'id')
            ? '''
  Future<${layout.pascal}Model> update(${layout.pascal}Model item) async {
    final index = _items.indexWhere((e) => e.id == item.id);
    if (index >= 0) {
      _items[index] = item;
    }
    return item;
  }'''
            : '''
  Future<${layout.pascal}Model> update(${layout.pascal}Model item) async {
    final index = _items.indexWhere((e) => e == item);
    if (index >= 0) {
      _items[index] = item;
    }
    return item;
  }''',
        fields.any((f) => f.name == 'id')
            ? '''
  Future<void> delete(String id) async {
    _items.removeWhere((e) => e.id == id);
  }'''
            : '''
  Future<void> delete(String id) async {
    _items.removeWhere((e) => e.toString().contains(id));
  }''',
      ],
    ];

    return '''
${layout.packageImport(project, layout.model)}

/// Generated by Chico Flutter DevKit — remote datasource (demo in-memory).
class ${layout.pascal}RemoteDataSource {
  final List<${layout.pascal}Model> _items = <${layout.pascal}Model>[
$seeds
  ];

${methods.join('\n')}
}
''';
  }

  String _localDatasource(
    FeatureLayout layout, {
    required String project,
    required List<FieldSpec> fields,
  }) {
    final seeds = _seedModels(layout, fields);
    return '''
${layout.packageImport(project, layout.model)}

/// Generated by Chico Flutter DevKit — local datasource (demo in-memory).
class ${layout.pascal}LocalDataSource {
  final List<${layout.pascal}Model> _cache = <${layout.pascal}Model>[
$seeds
  ];

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
    required bool includeRemote,
    required bool includeLocal,
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
        final dsImports = [
          if (includeRemote)
            layout.packageImport(project, layout.remoteDatasource),
          if (includeLocal)
            layout.packageImport(project, layout.localDatasource),
        ].join('\n');
        final dsProviders = [
          if (includeRemote)
            '''
final ${layout.snake}RemoteDataSourceProvider =
    Provider<${layout.pascal}RemoteDataSource>(
  (ref) => ${layout.pascal}RemoteDataSource(),
);''',
          if (includeLocal)
            '''
final ${layout.snake}LocalDataSourceProvider =
    Provider<${layout.pascal}LocalDataSource>(
  (ref) => ${layout.pascal}LocalDataSource(),
);''',
        ].join('\n');
        final repoArgs = [
          if (includeRemote)
            'remote: ref.watch(${layout.snake}RemoteDataSourceProvider)',
          if (includeLocal)
            'local: ref.watch(${layout.snake}LocalDataSourceProvider)',
        ].join(',\n    ');
        return [
          PlannedFileWrite(
            relativePath: '$dir/${layout.snake}_providers.dart',
            content:
                '''
import 'package:flutter_riverpod/flutter_riverpod.dart';

${layout.packageImport(project, layout.entity)}
${layout.packageImport(project, layout.getUseCase)}
${layout.packageImport(project, layout.repositoryContract)}
${layout.packageImport(project, layout.repositoryImpl)}
$dsImports

/// Generated by Chico Flutter DevKit — riverpod providers
$dsProviders

final ${layout.snake}RepositoryProvider =
    Provider<${layout.pascal}Repository>((ref) {
  return ${layout.pascal}RepositoryImpl(
    $repoArgs,
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

  String _titleExpr(List<FieldSpec> fields) {
    final names = fields.map((f) => f.name).toSet();
    if (names.contains('name')) return 'item.name';
    if (names.contains('title')) return 'item.title';
    if (names.contains('id')) return 'item.id';
    return 'item.toString()';
  }

  String _subtitleExpr(List<FieldSpec> fields) {
    final names = fields.map((f) => f.name).toSet();
    if (names.contains('description')) return 'item.description';
    if (names.contains('subtitle')) return 'item.subtitle';
    return 'null';
  }

  String _graphConstruction(
    FeatureLayout layout, {
    required bool includeRemote,
    required bool includeLocal,
    required DependencyInjection di,
  }) {
    return switch (di) {
      DependencyInjection.getIt =>
        '    final getList = getIt<Get${layout.pascal}List>();',
      DependencyInjection.manual =>
        '    final getList = FeatureFactories.${layout.camel}List();',
      DependencyInjection.riverpod =>
        '''
    final repository = ${layout.pascal}RepositoryImpl(${[if (includeRemote) 'remote: ${layout.pascal}RemoteDataSource()', if (includeLocal) 'local: ${layout.pascal}LocalDataSource()'].join(', ')});
    final getList = Get${layout.pascal}List(repository);''',
    };
  }

  String _pageDataImports({
    required FeatureLayout layout,
    required String project,
    required DependencyInjection di,
    required bool includeRemote,
    required bool includeLocal,
    required String tileImport,
  }) {
    return switch (di) {
      DependencyInjection.getIt => [
        layout.packageImport(project, layout.getUseCase),
        "import 'package:$project/core/di/injector.dart';",
        tileImport,
      ].join('\n'),
      DependencyInjection.manual => [
        layout.packageImport(project, layout.getUseCase),
        "import 'package:$project/core/di/feature_factories.dart';",
        tileImport,
      ].join('\n'),
      DependencyInjection.riverpod => [
        layout.packageImport(project, layout.getUseCase),
        layout.packageImport(project, layout.repositoryImpl),
        if (includeRemote)
          layout.packageImport(project, layout.remoteDatasource),
        if (includeLocal) layout.packageImport(project, layout.localDatasource),
        tileImport,
      ].join('\n'),
    };
  }

  String _page(
    FeatureLayout layout, {
    required StateManagement state,
    required String project,
    required bool useChico,
    required GenerationContext context,
    required List<FieldSpec> fields,
    required bool includeRemote,
    required bool includeLocal,
    required bool includeSearch,
    required bool includeFilters,
    required bool includePagination,
  }) {
    final hints = <String>[
      if (includeSearch) '// Search UI hook enabled.',
      if (includeFilters) '// Filters UI hook enabled.',
      if (includePagination) '// Pagination UI hook enabled.',
    ].map((line) => '    $line').join('\n');
    final title = _titleExpr(fields);
    final subtitle = _subtitleExpr(fields);
    final stateDir = layout.stateDir(state).split('/').last;
    final tileImport = layout.packageImport(project, layout.listTile);
    final di = context.config.flutter.dependencyInjection;
    final graph = _graphConstruction(
      layout,
      includeRemote: includeRemote,
      includeLocal: includeLocal,
      di: di,
    );

    final dataImports = _pageDataImports(
      layout: layout,
      project: project,
      di: di,
      includeRemote: includeRemote,
      includeLocal: includeLocal,
      tileImport: tileImport,
    );

    return switch (state) {
      StateManagement.bloc => _blocPage(
        layout: layout,
        useChico: useChico,
        context: context,
        hints: hints,
        title: title,
        subtitle: subtitle,
        stateDir: stateDir,
        dataImports: dataImports,
        graph: graph,
      ),
      StateManagement.cubit => _cubitPage(
        layout: layout,
        useChico: useChico,
        context: context,
        hints: hints,
        title: title,
        subtitle: subtitle,
        stateDir: stateDir,
        dataImports: dataImports,
        graph: graph,
      ),
      StateManagement.provider => _providerPage(
        layout: layout,
        useChico: useChico,
        context: context,
        hints: hints,
        title: title,
        subtitle: subtitle,
        stateDir: stateDir,
        dataImports: dataImports,
        graph: graph,
      ),
      StateManagement.riverpod => _riverpodPage(
        layout: layout,
        project: project,
        useChico: useChico,
        context: context,
        hints: hints,
        title: title,
        subtitle: subtitle,
        stateDir: stateDir,
        tileImport: tileImport,
      ),
    };
  }

  String _scaffold({
    required bool useChico,
    required GenerationContext context,
    required String title,
    required String body,
    required String imports,
  }) {
    if (useChico) {
      return '''
${UiImports.packageImport(context.config)}
$imports

/// Generated by Chico Flutter DevKit — wired demo list page
class ${title}Page extends StatelessWidget {
  const ${title}Page({super.key});

  @override
  Widget build(BuildContext context) {
$body
  }
}
''';
    }
    return '''
import 'package:flutter/material.dart';
$imports

/// Generated by Chico Flutter DevKit — wired demo list page
class ${title}Page extends StatelessWidget {
  const ${title}Page({super.key});

  @override
  Widget build(BuildContext context) {
$body
  }
}
''';
  }

  String _blocPage({
    required FeatureLayout layout,
    required bool useChico,
    required GenerationContext context,
    required String hints,
    required String title,
    required String subtitle,
    required String stateDir,
    required String dataImports,
    required String graph,
  }) {
    final onPressed = useChico ? 'onPressed' : 'onTap';
    final listBody = useChico
        ? '''
      return ChicoScaffold(
        bar: const ChicoBar(title: '${layout.pascal}'),
        body: ChicoPage(child: child),
      );'''
        : '''
      return Scaffold(
        appBar: AppBar(title: const Text('${layout.pascal}')),
        body: child,
      );''';

    final build =
        '''
$hints
$graph
    return BlocProvider(
      create: (_) => ${layout.pascal}Bloc(getList)
        ..add(const ${layout.pascal}Started()),
      child: BlocBuilder<${layout.pascal}Bloc, ${layout.pascal}State>(
        builder: (context, state) {
          final Widget child = switch (state) {
            ${layout.pascal}Loading() || ${layout.pascal}Initial() =>
              const Center(child: Text('Loading…')),
            ${layout.pascal}Failure(:final message) =>
              Center(child: Text(message)),
            ${layout.pascal}Loaded(:final items) when items.isEmpty =>
              const Center(child: Text('No items')),
            ${layout.pascal}Loaded(:final items) => ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  return ${layout.pascal}ListTile(
                    title: $title,
                    subtitle: $subtitle,
                    $onPressed: () {},
                  );
                },
              ),
          };
$listBody
        },
      ),
    );''';

    return _scaffold(
      useChico: useChico,
      context: context,
      title: layout.pascal,
      imports:
          '''
import 'package:flutter_bloc/flutter_bloc.dart';
$dataImports
import '../$stateDir/${layout.snake}_bloc.dart';
import '../$stateDir/${layout.snake}_event.dart';
import '../$stateDir/${layout.snake}_state.dart';
''',
      body: build,
    );
  }

  String _cubitPage({
    required FeatureLayout layout,
    required bool useChico,
    required GenerationContext context,
    required String hints,
    required String title,
    required String subtitle,
    required String stateDir,
    required String dataImports,
    required String graph,
  }) {
    final onPressed = useChico ? 'onPressed' : 'onTap';
    final listBody = useChico
        ? '''
      return ChicoScaffold(
        bar: const ChicoBar(title: '${layout.pascal}'),
        body: ChicoPage(child: child),
      );'''
        : '''
      return Scaffold(
        appBar: AppBar(title: const Text('${layout.pascal}')),
        body: child,
      );''';

    final build =
        '''
$hints
$graph
    return BlocProvider(
      create: (_) => ${layout.pascal}Cubit(getList)..load(),
      child: BlocBuilder<${layout.pascal}Cubit, ${layout.pascal}State>(
        builder: (context, state) {
          final Widget child = switch (state) {
            ${layout.pascal}Loading() || ${layout.pascal}Initial() =>
              const Center(child: Text('Loading…')),
            ${layout.pascal}Failure(:final message) =>
              Center(child: Text(message)),
            ${layout.pascal}Loaded(:final items) when items.isEmpty =>
              const Center(child: Text('No items')),
            ${layout.pascal}Loaded(:final items) => ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  return ${layout.pascal}ListTile(
                    title: $title,
                    subtitle: $subtitle,
                    $onPressed: () {},
                  );
                },
              ),
          };
$listBody
        },
      ),
    );''';

    return _scaffold(
      useChico: useChico,
      context: context,
      title: layout.pascal,
      imports:
          '''
import 'package:flutter_bloc/flutter_bloc.dart';
$dataImports
import '../$stateDir/${layout.snake}_cubit.dart';
import '../$stateDir/${layout.snake}_state.dart';
''',
      body: build,
    );
  }

  String _providerPage({
    required FeatureLayout layout,
    required bool useChico,
    required GenerationContext context,
    required String hints,
    required String title,
    required String subtitle,
    required String stateDir,
    required String dataImports,
    required String graph,
  }) {
    final onPressed = useChico ? 'onPressed' : 'onTap';
    final shell = useChico
        ? '''
        return ChicoScaffold(
          bar: const ChicoBar(title: '${layout.pascal}'),
          body: ChicoPage(child: child),
        );'''
        : '''
        return Scaffold(
          appBar: AppBar(title: const Text('${layout.pascal}')),
          body: child,
        );''';

    final build =
        '''
$hints
$graph
    return ChangeNotifierProvider(
      create: (_) => ${layout.pascal}Provider(getList)..load(),
      child: Consumer<${layout.pascal}Provider>(
        builder: (context, model, _) {
          final Widget child;
          if (model.loading) {
            child = const Center(child: Text('Loading…'));
          } else if (model.error != null) {
            child = Center(child: Text(model.error!));
          } else if (model.items.isEmpty) {
            child = const Center(child: Text('No items'));
          } else {
            child = ListView.builder(
              itemCount: model.items.length,
              itemBuilder: (context, index) {
                final item = model.items[index];
                return ${layout.pascal}ListTile(
                  title: $title,
                  subtitle: $subtitle,
                  $onPressed: () {},
                );
              },
            );
          }
$shell
        },
      ),
    );''';

    return _scaffold(
      useChico: useChico,
      context: context,
      title: layout.pascal,
      imports:
          '''
import 'package:provider/provider.dart';
$dataImports
import '../$stateDir/${layout.snake}_provider.dart';
''',
      body: build,
    );
  }

  String _riverpodPage({
    required FeatureLayout layout,
    required String project,
    required bool useChico,
    required GenerationContext context,
    required String hints,
    required String title,
    required String subtitle,
    required String stateDir,
    required String tileImport,
  }) {
    final onPressed = useChico ? 'onPressed' : 'onTap';
    final shell = useChico
        ? '''
    return ChicoScaffold(
      bar: const ChicoBar(title: '${layout.pascal}'),
      body: ChicoPage(child: child),
    );'''
        : '''
    return Scaffold(
      appBar: AppBar(title: const Text('${layout.pascal}')),
      body: child,
    );''';

    final uiImports = useChico
        ? UiImports.packageImport(context.config)
        : "import 'package:flutter/material.dart';";

    return '''
$uiImports
import 'package:flutter_riverpod/flutter_riverpod.dart';
$tileImport
${layout.packageImport(project, layout.entity)}
import '../$stateDir/${layout.snake}_providers.dart';

/// Generated by Chico Flutter DevKit — wired demo list page
class ${layout.pascal}Page extends ConsumerWidget {
  const ${layout.pascal}Page({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
$hints
    final asyncItems = ref.watch(${layout.snake}ListProvider);
    final Widget child = asyncItems.when(
      loading: () => const Center(child: Text('Loading…')),
      error: (error, _) => Center(child: Text('\$error')),
      data: (items) {
        if (items.isEmpty) {
          return const Center(child: Text('No items'));
        }
        return ListView.builder(
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return ${layout.pascal}ListTile(
              title: $title,
              subtitle: $subtitle,
              $onPressed: () {},
            );
          },
        );
      },
    );
$shell
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
