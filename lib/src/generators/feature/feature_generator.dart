import '../../config/models.dart';
import '../../core/exceptions.dart';
import '../../fs/custom_regions.dart';
import '../../fs/write_plan.dart';
import '../context.dart';
import '../result.dart';
import '../runner.dart';
import '../shared/chico_dependency_guard.dart';
import '../shared/code_builders.dart';
import '../shared/field_spec.dart';
import '../shared/ui_imports.dart';
import 'api_feature_wire.dart';
import 'feature_from_spec.dart';
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
    final spec = (context.extra['spec'] as String?)?.trim();
    final fromApi = (context.extra['fromApi'] as String?)?.trim();
    if (spec != null && spec.isNotEmpty) {
      FeatureFromSpec.validate(
        context: context,
        featureFields: _fields(context),
      );
    } else if (fromApi != null && fromApi.isNotEmpty) {
      if (!includeRemote) {
        throw const InvalidUsageException(
          '--from-api requires a remote datasource.',
          details: 'Omit --no-remote when wiring an API client.',
        );
      }
      // Fail closed before any writes (result discarded; generate re-resolves).
      ApiFeatureWire.resolve(
        projectRoot: context.projectRoot,
        apiName: fromApi,
        featureSnake: context.targetName.snakeCase,
        featureFields: _fields(context),
        needCrud: context.extra['crud'] == true,
        needPagination: context.extra['pagination'] == true,
        needSearch: context.extra['search'] == true,
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
    final useMaterialUi = await UiImports.projectUsesMaterialUi(
      context.projectRoot,
    );
    final spec = (context.extra['spec'] as String?)?.trim();
    var fromApi = (context.extra['fromApi'] as String?)?.trim();
    if (spec != null && spec.isNotEmpty) {
      // Pre-validated in validate(); generate API client then wire like --from-api.
      fromApi = await FeatureFromSpec.generateApiClient(context);
    }
    final apiWire = (fromApi != null && fromApi.isNotEmpty)
        ? ApiFeatureWire.resolve(
            projectRoot: context.projectRoot,
            apiName: fromApi,
            featureSnake: layout.snake,
            featureFields: fields,
            needCrud: includeCrud,
            needPagination: includePagination,
            needSearch: includeSearch,
          )
        : null;

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
        content: _listUseCases(
          layout,
          project: project,
          includePagination: includePagination,
          includeSearch: includeSearch,
        ),
      ),
      if (includeRemote)
        PlannedFileWrite(
          relativePath: layout.remoteDatasource,
          content: apiWire == null
              ? _remoteDatasource(
                  layout,
                  project: project,
                  fields: fields,
                  includeCrud: includeCrud,
                  includePagination: includePagination,
                  includeSearch: includeSearch,
                )
              : _remoteDatasourceFromApi(
                  layout,
                  project: project,
                  fields: fields,
                  wire: apiWire,
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
        includePagination: includePagination,
        includeSearch: includeSearch,
        apiWire: apiWire,
      ),
      PlannedFileWrite(
        relativePath: layout.page,
        content: _page(
          layout,
          state: state,
          project: project,
          useChico: useChico,
          useMaterialUi: useMaterialUi,
          context: context,
          fields: fields,
          includeRemote: includeRemote,
          includeLocal: includeLocal,
          includeSearch: includeSearch,
          includeFilters: includeFilters,
          includePagination: includePagination,
          apiWire: apiWire,
        ),
      ),
      PlannedFileWrite(
        relativePath: layout.listTile,
        content: _listTile(
          layout,
          useChico: useChico,
          useMaterialUi: useMaterialUi,
          context: context,
        ),
      ),
    ];

    writes.addAll(
      FeatureIntegration.planHooks(
        context: context,
        layout: layout,
        includeRemote: includeRemote,
        includeLocal: includeLocal,
        includePagination: includePagination,
        includeSearch: includeSearch,
        useMaterialUi: useMaterialUi,
        apiWire: apiWire,
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
      if (apiWire != null) {
        writes.add(
          PlannedFileWrite(
            relativePath:
                'test/features/${layout.snake}/${layout.snake}_remote_mapping_test.dart',
            content: _remoteMappingTest(
              layout,
              project: project,
              wire: apiWire,
              fields: fields,
            ),
          ),
        );
        writes.add(
          PlannedFileWrite(
            relativePath:
                'test/features/${layout.snake}/${layout.snake}_usecase_test.dart',
            content: _useCaseLoadTest(
              layout,
              project: project,
              fields: fields,
              includeCrud: includeCrud,
              includePagination: includePagination,
              includeSearch: includeSearch,
            ),
          ),
        );
      }
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

    final dataNote = apiWire == null
        ? 'demo in-memory data'
        : 'API client ${apiWire.clientPascal} (${apiWire.listMethod.name})';
    final nextHint = apiWire == null
        ? 'Swap the datasource for a real API when you are ready.'
        : 'Remote datasource calls ${apiWire.clientPascal}; ensure the API base URL is reachable.';

    return commitWrites(
      context: context,
      writes: writes,
      message:
          'Feature ${layout.pascal} generated with $dataNote '
          '(${architecture.yamlValue}/${state.yamlValue}'
          '${flags.isEmpty ? '' : '; $flags'}).\n'
          'Files planned: ${writes.length}\n'
          'Tests generated: $testCount\n'
          'Open /features/${layout.snake} from Home.\n'
          '$nextHint',
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

  String _listUseCases(
    FeatureLayout layout, {
    required String project,
    required bool includePagination,
    required bool includeSearch,
  }) {
    final extras = StringBuffer();
    if (includeSearch) {
      extras.writeln('''

/// Generated by Chico Flutter DevKit — search use case
class Search${layout.pascal} {
  const Search${layout.pascal}(this._repository);

  final ${layout.pascal}Repository _repository;

  Future<List<${layout.pascal}>> call(String query) =>
      _repository.search(query);
}''');
    }
    if (includePagination) {
      extras.writeln('''

/// Generated by Chico Flutter DevKit — page use case
class Get${layout.pascal}Page {
  const Get${layout.pascal}Page(this._repository);

  final ${layout.pascal}Repository _repository;

  Future<List<${layout.pascal}>> call({
    required int page,
    int pageSize = 20,
  }) =>
      _repository.fetchPage(page: page, pageSize: pageSize);
}''');
    }
    return '''
${layout.packageImport(project, layout.entity)}
${layout.packageImport(project, layout.repositoryContract)}

/// Generated by Chico Flutter DevKit — use case
class Get${layout.pascal}List {
  const Get${layout.pascal}List(this._repository);

  final ${layout.pascal}Repository _repository;

  Future<List<${layout.pascal}>> call() => _repository.fetchAll();
}
$extras''';
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

  String _remoteDatasourceFromApi(
    FeatureLayout layout, {
    required String project,
    required List<FieldSpec> fields,
    required ApiFeatureWirePlan wire,
    required bool includeCrud,
    required bool includePagination,
    required bool includeSearch,
  }) {
    final mapArgs = wire.mapFromDtoExpression();
    final fetchAll =
        '''
  Future<List<${layout.pascal}Model>> fetchAll() async {
    final dtos = await api.${wire.listMethod.name}();
    return dtos.map(mapDto).toList(growable: false);
  }''';

    final fetchPage = includePagination
        ? wire.listHasPage
              ? '''
  Future<List<${layout.pascal}Model>> fetchPage({
    required int page,
    int pageSize = 20,
  }) async {
    final dtos = await api.${wire.listMethod.name}(page: page);
    return dtos.map(mapDto).toList(growable: false);
  }'''
              : '''
  Future<List<${layout.pascal}Model>> fetchPage({
    required int page,
    int pageSize = 20,
  }) async {
    // API list has no page param — slice locally after fetchAll.
    final all = await fetchAll();
    final start = (page < 1 ? 0 : page - 1) * pageSize;
    if (start >= all.length) {
      return const <${layout.pascal}Model>[];
    }
    final end = (start + pageSize).clamp(0, all.length);
    return all.sublist(start, end);
  }'''
        : '';

    final search = includeSearch
        ? wire.listHasQuery
              ? '''
  Future<List<${layout.pascal}Model>> search(String query) async {
    final q = query.trim();
    if (q.isEmpty) return fetchAll();
    final dtos = await api.${wire.listMethod.name}(q: q);
    return dtos.map(mapDto).toList(growable: false);
  }'''
              : '''
  Future<List<${layout.pascal}Model>> search(String query) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return fetchAll();
    final all = await fetchAll();
    return all
        .where((item) => item.toString().toLowerCase().contains(q))
        .toList(growable: false);
  }'''
        : '';

    final crud = <String>[];
    if (includeCrud &&
        wire.createMethod != null &&
        wire.updateMethod != null &&
        wire.deleteMethod != null &&
        wire.inputType != null) {
      final inputArgs = wire.mapToInputExpression('item');
      final idParam = wire.idPathParam ?? 'id';
      crud.addAll([
        '''
  Future<${layout.pascal}Model> create(${layout.pascal}Model item) async {
    final body = ${wire.inputType}(
      $inputArgs
    );
    final dto = await api.${wire.createMethod!.name}(body: body);
    return mapDto(dto);
  }''',
        '''
  Future<${layout.pascal}Model> update(${layout.pascal}Model item) async {
    final body = ${wire.inputType}(
      $inputArgs
    );
    final dto = await api.${wire.updateMethod!.name}(
      $idParam: item.id,
      body: body,
    );
    return mapDto(dto);
  }''',
        '''
  Future<void> delete(String id) async {
    await api.${wire.deleteMethod!.name}($idParam: id);
  }''',
      ]);
    }

    final methods = [
      fetchAll,
      if (fetchPage.isNotEmpty) fetchPage,
      if (search.isNotEmpty) search,
      ...crud,
    ];

    return '''
${layout.packageImport(project, layout.model)}
${wire.clientImport}
${wire.modelsImport}

/// Generated by Chico Flutter DevKit — remote datasource (API: ${wire.clientPascal}).
class ${layout.pascal}RemoteDataSource {
  ${layout.pascal}RemoteDataSource({required this.api});

  final ${wire.clientPascal} api;

${methods.join('\n')}

  /// Public for unit tests; wrap custom logic in the custom region.
  ${layout.pascal}Model mapDto(${wire.itemType} dto) {
${CustomRegions.stub('remote.map', comment: 'Customize DTO → model mapping')}
    return ${layout.pascal}Model(
      $mapArgs
    );
  }
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
    if (includePagination) {
      if (includeRemote) {
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
      } else if (includeLocal) {
        extras.writeln('''
  @override
  Future<List<${layout.pascal}>> fetchPage({
    required int page,
    int pageSize = 20,
  }) async {
    final local = await _local.fetchAll();
    final start = (page < 1 ? 0 : page - 1) * pageSize;
    if (start >= local.length) {
      return const <${layout.pascal}>[];
    }
    final end = (start + pageSize).clamp(0, local.length);
    return local
        .sublist(start, end)
        .map((model) => model.toEntity())
        .toList(growable: false);
  }
''');
      }
    }
    if (includeSearch) {
      if (includeRemote) {
        extras.writeln('''
  @override
  Future<List<${layout.pascal}>> search(String query) async {
    final remote = await _remote.search(query);
    return remote.map((model) => model.toEntity()).toList(growable: false);
  }
''');
      } else if (includeLocal) {
        extras.writeln('''
  @override
  Future<List<${layout.pascal}>> search(String query) async {
    final q = query.trim().toLowerCase();
    final local = await _local.fetchAll();
    if (q.isEmpty) {
      return local.map((model) => model.toEntity()).toList(growable: false);
    }
    return local
        .where((item) => item.toString().toLowerCase().contains(q))
        .map((model) => model.toEntity())
        .toList(growable: false);
  }
''');
      }
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

  static const _pageSize = 20;

  String _loadedStateClass(
    FeatureLayout layout, {
    required bool includeSearch,
    required bool includePagination,
  }) {
    if (!includeSearch && !includePagination) {
      return '''
final class ${layout.pascal}Loaded extends ${layout.pascal}State {
  const ${layout.pascal}Loaded(this.items);

  final List<${layout.pascal}> items;
}''';
    }
    return '''
final class ${layout.pascal}Loaded extends ${layout.pascal}State {
  const ${layout.pascal}Loaded(
    this.items, {
    this.page = 1,
    this.query = '',
    this.hasMore = false,
  });

  final List<${layout.pascal}> items;
  final int page;
  final String query;
  final bool hasMore;
}''';
  }

  List<PlannedFileWrite> _stateFiles(
    FeatureLayout layout,
    StateManagement state, {
    required String project,
    required bool includeRemote,
    required bool includeLocal,
    required bool includePagination,
    required bool includeSearch,
    ApiFeatureWirePlan? apiWire,
  }) {
    final dir = layout.stateDir(state);
    final loaded = _loadedStateClass(
      layout,
      includeSearch: includeSearch,
      includePagination: includePagination,
    );
    // With pagination, initial/empty loads use GetPage — omit unused _getList.
    final needsGetList = !includePagination;
    final listField = needsGetList
        ? '''
  final Get${layout.pascal}List _getList;'''
        : '';
    final searchField = includeSearch
        ? '''
  final Search${layout.pascal} _search;'''
        : '';
    final pageField = includePagination
        ? '''
  final Get${layout.pascal}Page _getPage;'''
        : '';
    final blocCtorParams = [
      if (needsGetList) 'this._getList',
      if (includeSearch) 'this._search',
      if (includePagination) 'this._getPage',
    ].join(', ');
    final searchEvent = includeSearch
        ? '''

final class ${layout.pascal}Searched extends ${layout.pascal}Event {
  const ${layout.pascal}Searched(this.query);

  final String query;
}'''
        : '';
    final pageEvent = includePagination
        ? '''

final class ${layout.pascal}PageRequested extends ${layout.pascal}Event {
  const ${layout.pascal}PageRequested(this.page);

  final int page;
}'''
        : '';

    switch (state) {
      case StateManagement.bloc:
        final registerSearch = includeSearch
            ? '''
    on<${layout.pascal}Searched>(_onSearched);'''
            : '';
        final registerPage = includePagination
            ? '''
    on<${layout.pascal}PageRequested>(_onPageRequested);'''
            : '';
        final startedBody = includePagination
            ? '''
      const page = 1;
      final items = await _getPage(page: page, pageSize: $_pageSize);
      emit(${layout.pascal}Loaded(
        items,
        page: page,
        hasMore: items.length >= $_pageSize,
      ));'''
            : '''
      final items = await _getList();
      emit(${layout.pascal}Loaded(items));''';
        final searchHandler = includeSearch
            ? '''

  Future<void> _onSearched(
    ${layout.pascal}Searched event,
    Emitter<${layout.pascal}State> emit,
  ) async {
    emit(const ${layout.pascal}Loading());
    try {
      final query = event.query;
      if (query.trim().isEmpty) {
        ${includePagination ? '''
        const page = 1;
        final items = await _getPage(page: page, pageSize: $_pageSize);
        emit(${layout.pascal}Loaded(
          items,
          page: page,
          query: '',
          hasMore: items.length >= $_pageSize,
        ));''' : '''
        final items = await _getList();
        emit(${layout.pascal}Loaded(items, query: ''));'''}
      } else {
        final items = await _search(query);
        emit(${layout.pascal}Loaded(
          items,
          query: query,
          page: 1,
          hasMore: false,
        ));
      }
    } catch (error) {
      emit(${layout.pascal}Failure(error.toString()));
    }
  }'''
            : '';
        final pageHandler = includePagination
            ? '''

  Future<void> _onPageRequested(
    ${layout.pascal}PageRequested event,
    Emitter<${layout.pascal}State> emit,
  ) async {
    emit(const ${layout.pascal}Loading());
    try {
      final items = await _getPage(page: event.page, pageSize: $_pageSize);
      emit(${layout.pascal}Loaded(
        items,
        page: event.page,
        hasMore: items.length >= $_pageSize,
      ));
    } catch (error) {
      emit(${layout.pascal}Failure(error.toString()));
    }
  }'''
            : '';
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
}$searchEvent$pageEvent
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

$loaded

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
  ${layout.pascal}Bloc($blocCtorParams) : super(const ${layout.pascal}Initial()) {
    on<${layout.pascal}Started>(_onStarted);
    on<${layout.pascal}Refreshed>(_onStarted);$registerSearch$registerPage
  }

$listField$searchField$pageField

  Future<void> _onStarted(
    ${layout.pascal}Event event,
    Emitter<${layout.pascal}State> emit,
  ) async {
    emit(const ${layout.pascal}Loading());
    try {
$startedBody
    } catch (error) {
      emit(${layout.pascal}Failure(error.toString()));
    }
  }$searchHandler$pageHandler
}
''',
          ),
        ];
      case StateManagement.cubit:
        final cubitCtor = [
          if (needsGetList) 'this._getList',
          if (includeSearch) 'this._search',
          if (includePagination) 'this._getPage',
        ].join(', ');
        final searchMethod = includeSearch
            ? '''

  Future<void> search(String query) async {
    emit(const ${layout.pascal}Loading());
    try {
      if (query.trim().isEmpty) {
        await load();
        return;
      }
      final items = await _search(query);
      emit(${layout.pascal}Loaded(
        items,
        query: query,
        page: 1,
        hasMore: false,
      ));
    } catch (error) {
      emit(${layout.pascal}Failure(error.toString()));
    }
  }'''
            : '';
        final pageMethod = includePagination
            ? '''

  Future<void> loadPage(int page) async {
    emit(const ${layout.pascal}Loading());
    try {
      final items = await _getPage(page: page, pageSize: $_pageSize);
      emit(${layout.pascal}Loaded(
        items,
        page: page,
        hasMore: items.length >= $_pageSize,
      ));
    } catch (error) {
      emit(${layout.pascal}Failure(error.toString()));
    }
  }'''
            : '';
        final loadBody = includePagination
            ? '''
      const page = 1;
      final items = await _getPage(page: page, pageSize: $_pageSize);
      emit(${layout.pascal}Loaded(
        items,
        page: page,
        hasMore: items.length >= $_pageSize,
      ));'''
            : '''
      final items = await _getList();
      emit(${layout.pascal}Loaded(items));''';
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

$loaded

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
  ${layout.pascal}Cubit($cubitCtor) : super(const ${layout.pascal}Initial());

$listField$searchField$pageField

  Future<void> load() async {
    emit(const ${layout.pascal}Loading());
    try {
$loadBody
    } catch (error) {
      emit(${layout.pascal}Failure(error.toString()));
    }
  }$searchMethod$pageMethod
}
''',
          ),
        ];
      case StateManagement.riverpod:
        final dsImports = [
          if (apiWire != null) apiWire.clientImport,
          if (includeRemote)
            layout.packageImport(project, layout.remoteDatasource),
          if (includeLocal)
            layout.packageImport(project, layout.localDatasource),
        ].join('\n');
        final remoteCtor = apiWire == null
            ? '${layout.pascal}RemoteDataSource()'
            : '${layout.pascal}RemoteDataSource(api: ref.watch(${apiWire.apiSnake}ApiProvider))';
        final apiProvider = apiWire == null
            ? ''
            : '''
final ${apiWire.apiSnake}ApiProvider = Provider<${apiWire.clientPascal}>(
  (ref) => ${apiWire.clientPascal}(),
);
''';
        final dsProviders = [
          if (apiWire != null) apiProvider,
          if (includeRemote)
            '''
final ${layout.snake}RemoteDataSourceProvider =
    Provider<${layout.pascal}RemoteDataSource>(
  (ref) => $remoteCtor,
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
        final queryProvider = includeSearch
            ? '''
final ${layout.snake}QueryProvider = StateProvider<String>((ref) => '');
'''
            : '';
        final pageProvider = includePagination
            ? '''
final ${layout.snake}PageProvider = StateProvider<int>((ref) => 1);
'''
            : '';
        final listBody = includeSearch || includePagination
            ? '''
  ${includeSearch ? 'final query = ref.watch(${layout.snake}QueryProvider);' : ''}
  ${includePagination ? 'final page = ref.watch(${layout.snake}PageProvider);' : ''}
  final repo = ref.watch(${layout.snake}RepositoryProvider);
  ${includeSearch ? '''
  if (query.trim().isNotEmpty) {
    return repo.search(query);
  }''' : ''}
  ${includePagination ? '''
  return repo.fetchPage(page: page, pageSize: $_pageSize);''' : '''
  return ref.watch(get${layout.pascal}ListProvider)();'''}'''
            : '''
  return ref.watch(get${layout.pascal}ListProvider)();''';
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

${needsGetList ? '''
final get${layout.pascal}ListProvider = Provider<Get${layout.pascal}List>((ref) {
  return Get${layout.pascal}List(ref.watch(${layout.snake}RepositoryProvider));
});
''' : ''}$queryProvider$pageProvider
final ${layout.snake}ListProvider =
    FutureProvider<List<${layout.pascal}>>((ref) async {
$listBody
});
''',
          ),
        ];
      case StateManagement.provider:
        final providerCtor = [
          if (needsGetList) 'this._getList',
          if (includeSearch) 'this._search',
          if (includePagination) 'this._getPage',
        ].join(', ');
        final extraFields = StringBuffer();
        if (includeSearch || includePagination) {
          extraFields.writeln('  int page = 1;');
          extraFields.writeln("  String query = '';");
          extraFields.writeln('  bool hasMore = false;');
        }
        final searchMethod = includeSearch
            ? '''

  Future<void> search(String value) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      query = value;
      if (value.trim().isEmpty) {
        await load();
        return;
      }
      items = await _search(value);
      page = 1;
      hasMore = false;
    } catch (err) {
      error = err.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }'''
            : '';
        final pageMethod = includePagination
            ? '''

  Future<void> loadPage(int nextPage) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      items = await _getPage(page: nextPage, pageSize: $_pageSize);
      page = nextPage;
      query = '';
      hasMore = items.length >= $_pageSize;
    } catch (err) {
      error = err.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }'''
            : '';
        final loadBody = includePagination
            ? '''
      items = await _getPage(page: 1, pageSize: $_pageSize);
      page = 1;
      query = '';
      hasMore = items.length >= $_pageSize;'''
            : '''
      items = await _getList();''';
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
  ${layout.pascal}Provider($providerCtor);

$listField$searchField$pageField

  bool loading = false;
  String? error;
  List<${layout.pascal}> items = const [];
$extraFields
  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
$loadBody
    } catch (err) {
      error = err.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }$searchMethod$pageMethod
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
    required bool includeSearch,
    required bool includePagination,
    required DependencyInjection di,
    ApiFeatureWirePlan? apiWire,
  }) {
    final remoteExpr = apiWire == null
        ? '${layout.pascal}RemoteDataSource()'
        : '${layout.pascal}RemoteDataSource(api: ${apiWire.clientPascal}())';
    final repoCtor =
        '${layout.pascal}RepositoryImpl(${[if (includeRemote) 'remote: $remoteExpr', if (includeLocal) 'local: ${layout.pascal}LocalDataSource()'].join(', ')})';
    final needsGetList = !includePagination;
    return switch (di) {
      DependencyInjection.getIt => [
        if (needsGetList)
          '    final getList = getIt<Get${layout.pascal}List>();',
        if (includeSearch)
          '    final search = getIt<Search${layout.pascal}>();',
        if (includePagination)
          '    final getPage = getIt<Get${layout.pascal}Page>();',
      ].join('\n'),
      DependencyInjection.manual => [
        if (needsGetList)
          '    final getList = FeatureFactories.${layout.camel}List();',
        if (includeSearch)
          '    final search = FeatureFactories.${layout.camel}Search();',
        if (includePagination)
          '    final getPage = FeatureFactories.${layout.camel}Page();',
      ].join('\n'),
      DependencyInjection.riverpod =>
        '''
    final repository = $repoCtor;
${needsGetList ? '    final getList = Get${layout.pascal}List(repository);' : ''}
${includeSearch ? '    final search = Search${layout.pascal}(repository);' : ''}
${includePagination ? '    final getPage = Get${layout.pascal}Page(repository);' : ''}''',
    };
  }

  String _blocCreateArgs({
    required bool includeSearch,
    required bool includePagination,
  }) {
    final args = [
      if (!includePagination) 'getList',
      if (includeSearch) 'search',
      if (includePagination) 'getPage',
    ];
    return args.join(', ');
  }

  String _pageDataImports({
    required FeatureLayout layout,
    required String project,
    required DependencyInjection di,
    required bool includeRemote,
    required bool includeLocal,
    required String tileImport,
    ApiFeatureWirePlan? apiWire,
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
        if (apiWire != null) apiWire.clientImport,
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
    required bool useMaterialUi,
    required GenerationContext context,
    required List<FieldSpec> fields,
    required bool includeRemote,
    required bool includeLocal,
    required bool includeSearch,
    required bool includeFilters,
    required bool includePagination,
    ApiFeatureWirePlan? apiWire,
  }) {
    final filterHint = includeFilters
        ? '    // Filters: add chip/filter UI when your domain is ready.\n'
        : '';
    final title = _titleExpr(fields);
    final subtitle = _subtitleExpr(fields);
    final stateDir = layout.stateDir(state).split('/').last;
    final tileImport = layout.packageImport(project, layout.listTile);
    final di = context.config.flutter.dependencyInjection;
    final graph = _graphConstruction(
      layout,
      includeRemote: includeRemote,
      includeLocal: includeLocal,
      includeSearch: includeSearch,
      includePagination: includePagination,
      di: di,
      apiWire: apiWire,
    );

    final dataImports = _pageDataImports(
      layout: layout,
      project: project,
      di: di,
      includeRemote: includeRemote,
      includeLocal: includeLocal,
      tileImport: tileImport,
      apiWire: apiWire,
    );

    return switch (state) {
      StateManagement.bloc => _blocPage(
        layout: layout,
        useChico: useChico,
        useMaterialUi: useMaterialUi,
        context: context,
        hints: filterHint,
        title: title,
        subtitle: subtitle,
        stateDir: stateDir,
        dataImports: dataImports,
        graph: graph,
        includeSearch: includeSearch,
        includePagination: includePagination,
      ),
      StateManagement.cubit => _cubitPage(
        layout: layout,
        useChico: useChico,
        useMaterialUi: useMaterialUi,
        context: context,
        hints: filterHint,
        title: title,
        subtitle: subtitle,
        stateDir: stateDir,
        dataImports: dataImports,
        graph: graph,
        includeSearch: includeSearch,
        includePagination: includePagination,
      ),
      StateManagement.provider => _providerPage(
        layout: layout,
        useChico: useChico,
        useMaterialUi: useMaterialUi,
        context: context,
        hints: filterHint,
        title: title,
        subtitle: subtitle,
        stateDir: stateDir,
        dataImports: dataImports,
        graph: graph,
        includeSearch: includeSearch,
        includePagination: includePagination,
      ),
      StateManagement.riverpod => _riverpodPage(
        layout: layout,
        project: project,
        useChico: useChico,
        useMaterialUi: useMaterialUi,
        context: context,
        hints: filterHint,
        title: title,
        subtitle: subtitle,
        stateDir: stateDir,
        tileImport: tileImport,
        includeSearch: includeSearch,
        includePagination: includePagination,
      ),
    };
  }

  String _searchField({required String onChanged}) =>
      '''
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search…',
                    border: OutlineInputBorder(),
                    isDense: true,
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (query) {
                    $onChanged
                  },
                ),
              ),''';

  String _paginationBar({
    required String previousOnPressed,
    required String nextOnPressed,
  }) =>
      '''
              Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: $previousOnPressed,
                      child: const Text('Previous'),
                    ),
                    TextButton(
                      onPressed: $nextOnPressed,
                      child: const Text('Next'),
                    ),
                  ],
                ),
              ),''';

  String _scaffold({
    required bool useChico,
    required bool useMaterialUi,
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
${UiImports.materialImport(useMaterialUi: useMaterialUi)}
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
    required bool useMaterialUi,
    required GenerationContext context,
    required String hints,
    required String title,
    required String subtitle,
    required String stateDir,
    required String dataImports,
    required String graph,
    required bool includeSearch,
    required bool includePagination,
  }) {
    final onPressed = useChico ? 'onPressed' : 'onTap';
    final createArgs = _blocCreateArgs(
      includeSearch: includeSearch,
      includePagination: includePagination,
    );
    final chromeTop = includeSearch
        ? _searchField(
            onChanged:
                "context.read<${layout.pascal}Bloc>().add(${layout.pascal}Searched(query));",
          )
        : '';
    final chromeBottom = includePagination
        ? _paginationBar(
            previousOnPressed:
                '''state is ${layout.pascal}Loaded && state.page > 1
                        ? () => context.read<${layout.pascal}Bloc>().add(
                              ${layout.pascal}PageRequested(state.page - 1),
                            )
                        : null''',
            nextOnPressed:
                '''state is ${layout.pascal}Loaded && state.hasMore
                        ? () => context.read<${layout.pascal}Bloc>().add(
                              ${layout.pascal}PageRequested(state.page + 1),
                            )
                        : null''',
          )
        : '';
    final listBody = useChico
        ? '''
      return ChicoScaffold(
        bar: const ChicoBar(title: '${layout.pascal}'),
        body: ChicoPage(
          child: Column(
            children: [
$chromeTop
              Expanded(child: child),
$chromeBottom
            ],
          ),
        ),
      );'''
        : '''
      return Scaffold(
        appBar: AppBar(title: const Text('${layout.pascal}')),
        body: Column(
          children: [
$chromeTop
            Expanded(child: child),
$chromeBottom
          ],
        ),
      );''';

    final build =
        '''
$hints
$graph
    return BlocProvider(
      create: (_) => ${layout.pascal}Bloc($createArgs)
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
      useMaterialUi: useMaterialUi,
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
    required bool useMaterialUi,
    required GenerationContext context,
    required String hints,
    required String title,
    required String subtitle,
    required String stateDir,
    required String dataImports,
    required String graph,
    required bool includeSearch,
    required bool includePagination,
  }) {
    final onPressed = useChico ? 'onPressed' : 'onTap';
    final createArgs = _blocCreateArgs(
      includeSearch: includeSearch,
      includePagination: includePagination,
    );
    final chromeTop = includeSearch
        ? _searchField(
            onChanged: "context.read<${layout.pascal}Cubit>().search(query);",
          )
        : '';
    final chromeBottom = includePagination
        ? _paginationBar(
            previousOnPressed:
                '''state is ${layout.pascal}Loaded && state.page > 1
                        ? () => context.read<${layout.pascal}Cubit>().loadPage(
                              state.page - 1,
                            )
                        : null''',
            nextOnPressed:
                '''state is ${layout.pascal}Loaded && state.hasMore
                        ? () => context.read<${layout.pascal}Cubit>().loadPage(
                              state.page + 1,
                            )
                        : null''',
          )
        : '';
    final listBody = useChico
        ? '''
      return ChicoScaffold(
        bar: const ChicoBar(title: '${layout.pascal}'),
        body: ChicoPage(
          child: Column(
            children: [
$chromeTop
              Expanded(child: child),
$chromeBottom
            ],
          ),
        ),
      );'''
        : '''
      return Scaffold(
        appBar: AppBar(title: const Text('${layout.pascal}')),
        body: Column(
          children: [
$chromeTop
            Expanded(child: child),
$chromeBottom
          ],
        ),
      );''';

    final build =
        '''
$hints
$graph
    return BlocProvider(
      create: (_) => ${layout.pascal}Cubit($createArgs)..load(),
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
      useMaterialUi: useMaterialUi,
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
    required bool useMaterialUi,
    required GenerationContext context,
    required String hints,
    required String title,
    required String subtitle,
    required String stateDir,
    required String dataImports,
    required String graph,
    required bool includeSearch,
    required bool includePagination,
  }) {
    final onPressed = useChico ? 'onPressed' : 'onTap';
    final createArgs = _blocCreateArgs(
      includeSearch: includeSearch,
      includePagination: includePagination,
    );
    final chromeTop = includeSearch
        ? _searchField(onChanged: 'model.search(query);')
        : '';
    final chromeBottom = includePagination
        ? _paginationBar(
            previousOnPressed:
                '''model.page > 1 ? () => model.loadPage(model.page - 1) : null''',
            nextOnPressed:
                '''model.hasMore ? () => model.loadPage(model.page + 1) : null''',
          )
        : '';
    final shell = useChico
        ? '''
        return ChicoScaffold(
          bar: const ChicoBar(title: '${layout.pascal}'),
          body: ChicoPage(
            child: Column(
              children: [
$chromeTop
                Expanded(child: child),
$chromeBottom
              ],
            ),
          ),
        );'''
        : '''
        return Scaffold(
          appBar: AppBar(title: const Text('${layout.pascal}')),
          body: Column(
            children: [
$chromeTop
              Expanded(child: child),
$chromeBottom
            ],
          ),
        );''';

    final build =
        '''
$hints
$graph
    return ChangeNotifierProvider(
      create: (_) => ${layout.pascal}Provider($createArgs)..load(),
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
      useMaterialUi: useMaterialUi,
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
    required bool useMaterialUi,
    required GenerationContext context,
    required String hints,
    required String title,
    required String subtitle,
    required String stateDir,
    required String tileImport,
    required bool includeSearch,
    required bool includePagination,
  }) {
    final onPressed = useChico ? 'onPressed' : 'onTap';
    final chromeTop = includeSearch
        ? _searchField(
            onChanged:
                '''ref.read(${layout.snake}QueryProvider.notifier).state = query;
                    ${includePagination ? 'ref.read(${layout.snake}PageProvider.notifier).state = 1;' : ''}''',
          )
        : '';
    final chromeBottom = includePagination
        ? _paginationBar(
            previousOnPressed:
                '''ref.watch(${layout.snake}PageProvider) > 1
                        ? () => ref.read(${layout.snake}PageProvider.notifier).state =
                              ref.read(${layout.snake}PageProvider) - 1
                        : null''',
            nextOnPressed:
                '''(asyncItems.valueOrNull?.length ?? 0) >= $_pageSize
                        ? () => ref.read(${layout.snake}PageProvider.notifier).state =
                              ref.read(${layout.snake}PageProvider) + 1
                        : null''',
          )
        : '';
    final shell = useChico
        ? '''
    return ChicoScaffold(
      bar: const ChicoBar(title: '${layout.pascal}'),
      body: ChicoPage(
        child: Column(
          children: [
$chromeTop
            Expanded(child: child),
$chromeBottom
          ],
        ),
      ),
    );'''
        : '''
    return Scaffold(
      appBar: AppBar(title: const Text('${layout.pascal}')),
      body: Column(
        children: [
$chromeTop
          Expanded(child: child),
$chromeBottom
        ],
      ),
    );''';

    final uiImports = useChico
        ? UiImports.packageImport(context.config)
        : UiImports.materialImport(useMaterialUi: useMaterialUi);

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
    required bool useMaterialUi,
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
${UiImports.materialImport(useMaterialUi: useMaterialUi)}

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

  String _remoteMappingTest(
    FeatureLayout layout, {
    required String project,
    required ApiFeatureWirePlan wire,
    required List<FieldSpec> fields,
  }) {
    final jsonEntries = <String>[
      for (final m in wire.mappings)
        if (m.dtoFieldName != null) "'${m.dtoFieldName}': 'sample'",
      // Common OpenAPI required extras (e.g. Product.status enum as string).
      "'status': 'draft'",
      "'price': 1.0",
    ];
    final expectName = fields.any((f) => f.name == 'name')
        ? '    expect(model.name, isNotEmpty);\n'
        : '';
    return '''
import 'package:flutter_test/flutter_test.dart';

${wire.clientImport}
${wire.modelsImport}
${layout.packageImport(project, layout.remoteDatasource)}

void main() {
  test('${layout.pascal}RemoteDataSource.mapDto maps ${wire.itemType}', () {
    final api = ${wire.clientPascal}(baseUrl: 'http://127.0.0.1');
    final remote = ${layout.pascal}RemoteDataSource(api: api);
    final dto = ${wire.itemType}.fromJson(<String, dynamic>{
      ${jsonEntries.join(',\n      ')},
    });
    final model = remote.mapDto(dto);
    expect(model.id, isNotEmpty);
$expectName  });
}
''';
  }

  String _useCaseLoadTest(
    FeatureLayout layout, {
    required String project,
    required List<FieldSpec> fields,
    required bool includeCrud,
    required bool includePagination,
    required bool includeSearch,
  }) {
    final sampleArgs = fields
        .map((f) {
          if (f.name == 'id') return "      id: '1',";
          if (f.type == 'String') {
            return f.isNullable
                ? '      ${f.name}: null,'
                : "      ${f.name}: '${f.name}',";
          }
          if (f.type == 'int') return '      ${f.name}: 1,';
          if (f.type == 'double') return '      ${f.name}: 1.0,';
          if (f.type == 'bool') return '      ${f.name}: true,';
          return f.isNullable
              ? '      ${f.name}: null,'
              : "      ${f.name}: '',";
        })
        .join('\n');
    final extraMethods = <String>[
      if (includePagination)
        '''
  @override
  Future<List<${layout.pascal}>> fetchPage({required int page, int pageSize = 20}) async =>
      fetchAll();''',
      if (includeSearch)
        '''
  @override
  Future<List<${layout.pascal}>> search(String query) async => fetchAll();''',
      if (includeCrud) ...[
        '''
  @override
  Future<${layout.pascal}> create(${layout.pascal} item) async => item;''',
        '''
  @override
  Future<${layout.pascal}> update(${layout.pascal} item) async => item;''',
        '''
  @override
  Future<void> delete(String id) async {}''',
      ],
    ].join('\n');
    return '''
import 'package:flutter_test/flutter_test.dart';

${layout.packageImport(project, layout.entity)}
${layout.packageImport(project, layout.repositoryContract)}
${layout.packageImport(project, layout.getUseCase)}

class _Fake${layout.pascal}Repository implements ${layout.pascal}Repository {
  _Fake${layout.pascal}Repository(this._items, {this.throwOnCall = false});
  final List<${layout.pascal}> _items;
  final bool throwOnCall;

  @override
  Future<List<${layout.pascal}>> fetchAll() async {
    if (throwOnCall) throw Exception('boom');
    return _items;
  }
$extraMethods
}

void main() {
  test('Get${layout.pascal}List returns repository items', () async {
    final item = ${layout.pascal}(
$sampleArgs
    );
    final useCase = Get${layout.pascal}List(
      _Fake${layout.pascal}Repository([item]),
    );
    final result = await useCase();
    expect(result, hasLength(1));
    expect(result.first.id, item.id);
  });

  test('Get${layout.pascal}List surfaces repository errors', () async {
    final useCase = Get${layout.pascal}List(
      _Fake${layout.pascal}Repository(const [], throwOnCall: true),
    );
    expect(useCase(), throwsA(isA<Exception>()));
  });
}
''';
  }
}
