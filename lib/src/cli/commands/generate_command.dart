import 'dart:io';

import '../../config/models.dart';
import '../../config/overrides.dart';
import '../../core/exceptions.dart';
import '../../core/exit_codes.dart';
import '../../fs/write_plan.dart';
import '../../generators/registry.dart';
import '../../generators/runner.dart';
import '../command.dart';

/// `devkit generate <type> <name>` — runs a registered generator.
final class GenerateCommand extends DevKitCommand {
  GenerateCommand({
    required super.logger,
    required super.configService,
    required super.projectRootProvider,
    required this.registry,
    GeneratorRunner? runner,
  }) : _runner = runner {
    argParser
      ..addFlag(
        'dry-run',
        help: 'Preview planned files without writing.',
        negatable: false,
      )
      ..addFlag(
        'force',
        abbr: 'f',
        help: 'Overwrite existing files (respects backup settings).',
        negatable: false,
      )
      ..addFlag(
        'tests',
        help: 'Generate tests (use --no-tests to skip).',
        defaultsTo: true,
      )
      ..addFlag(
        'crud',
        help: 'Include CRUD repository methods.',
        negatable: false,
      )
      ..addFlag(
        'pagination',
        help: 'Include pagination APIs/UI hooks.',
        negatable: false,
      )
      ..addFlag(
        'search',
        help: 'Include search APIs/UI hooks.',
        negatable: false,
      )
      ..addFlag('filters', help: 'Include filter UI hooks.', negatable: false)
      ..addFlag(
        'local',
        help: 'Include a local datasource (features).',
        negatable: false,
      )
      ..addFlag(
        'remote',
        help: 'Include a remote datasource (features, default true).',
        defaultsTo: true,
      )
      ..addOption(
        'architecture',
        help: 'Override architecture for this generation.',
        allowed: Architecture.values.map((e) => e.yamlValue),
      )
      ..addOption(
        'state',
        help: 'Override state management for this generation.',
        allowed: StateManagement.values.map((e) => e.yamlValue),
      )
      ..addOption(
        'fields',
        help: 'Model/entity fields: id:String,name:String,price:double?',
      )
      ..addOption(
        'from-json',
        help: 'Path to a JSON file used to infer model fields.',
      )
      ..addOption(
        'feature',
        help: 'Optional feature name for feature-local placement.',
      )
      ..addOption(
        'values',
        help: 'Comma-separated enum values (enum generator).',
      )
      ..addOption(
        'on',
        help: 'Target type for extension generator (e.g. String).',
      )
      ..addOption(
        'kind',
        allowed: ['unit', 'widget'],
        help: 'Test kind for test generator.',
        defaultsTo: 'unit',
      )
      ..addOption(
        'target',
        help:
            'Logical target folder/type for test generator (model, service, …).',
      )
      ..addOption(
        'from-api',
        help:
            'Wire feature remote datasource to a generated API client '
            '(e.g. shop → lib/api/shop/generated).',
      )
      ..addOption(
        'api-name',
        help:
            'API client name when using feature --spec '
            '(default: feature name → lib/api/<name>).',
      )
      ..addFlag(
        'sync',
        help:
            'Refresh unchanged generated files recorded in the generate '
            'manifest (does not overwrite user edits).',
        negatable: false,
      )
      ..addFlag(
        'ui',
        help: 'Include UI screens (auth session --ui).',
        negatable: false,
      )
      ..addOption(
        'spec',
        help:
            'OpenAPI 3.x YAML/JSON path (api generator, or feature --spec to '
            'generate client + wire feature in one step).',
      )
      ..addOption(
        'base-url',
        help: 'Override the OpenAPI servers[0] base URL (api generator).',
      )
      ..addOption(
        'output',
        help: 'Output directory for the API client (default: lib/api/<name>).',
      )
      ..addFlag(
        'add-missing-chico',
        negatable: false,
        help:
            'Add missing Chico packages required by generated UI to pubspec '
            '(never modifies pubspec during --dry-run).',
      );
  }

  final GeneratorRegistry registry;
  final GeneratorRunner? _runner;

  @override
  String get name => 'generate';

  @override
  String get description =>
      'Generate features, models, screens, and other project assets.';

  @override
  String get invocation =>
      '${runner!.executableName} generate <type> <name> [arguments]';

  @override
  Future<int> run() async {
    final rest = argResults!.rest;
    if (rest.isEmpty) {
      throw InvalidUsageException(
        'Missing generator type.',
        details:
            'Available: ${registry.names.join(', ')}\n'
            'Example: devkit generate feature products',
      );
    }

    if (rest.length < 2) {
      throw const InvalidUsageException(
        'Expected: generate <type> <name>',
        details: 'Example: devkit generate feature products',
      );
    }

    final type = rest[0];
    final targetName = rest[1];
    final dryRun = argResults!['dry-run'] as bool;
    final force = argResults!['force'] as bool;
    final sync = argResults!['sync'] as bool;

    final architectureRaw = argResults!['architecture'] as String?;
    final stateRaw = argResults!['state'] as String?;

    final overrides = ConfigOverrides(
      architecture: architectureRaw == null
          ? null
          : Architecture.parse(architectureRaw),
      stateManagement: stateRaw == null
          ? null
          : StateManagement.parse(stateRaw),
    );

    final extra = <String, Object?>{
      'crud': argResults!['crud'] as bool,
      'pagination': argResults!['pagination'] as bool,
      'search': argResults!['search'] as bool,
      'filters': argResults!['filters'] as bool,
      'local': argResults!['local'] as bool,
      'remote': argResults!['remote'] as bool,
      'architecture': ?architectureRaw,
      'state': ?stateRaw,
      'fields': ?argResults!['fields'],
      'feature': ?argResults!['feature'],
      'values': ?argResults!['values'],
      'on': ?argResults!['on'],
      'kind': ?argResults!['kind'],
      'target': ?argResults!['target'],
      'spec': ?argResults!['spec'],
      'baseUrl': ?argResults!['base-url'],
      'output': ?argResults!['output'],
      'fromApi': ?argResults!['from-api'],
      'apiName': ?argResults!['api-name'],
      'sync': sync,
      'ui': argResults!['ui'] as bool,
      'addMissingChico': argResults!['add-missing-chico'] as bool,
    };

    if (argResults!.wasParsed('tests')) {
      extra['tests'] = argResults!['tests'] as bool;
    }

    final fromJsonPath = argResults!['from-json'] as String?;
    if (fromJsonPath != null) {
      final file = File(fromJsonPath);
      if (!file.existsSync()) {
        throw InvalidUsageException(
          'JSON file not found.',
          details: fromJsonPath,
        );
      }
      extra['fromJson'] = await file.readAsString();
    }

    final runner =
        _runner ??
        GeneratorRunner(registry: registry, configService: configService);

    final result = await runner.run(
      projectRoot: projectRootProvider(),
      generatorName: type,
      targetName: targetName,
      overrides: overrides,
      dryRun: dryRun,
      force: force,
      sync: sync,
      extra: extra,
    );

    if (dryRun) {
      logger.info('Dry run — planned files:');
    } else {
      logger.success('Generation complete: ${result.generatorName}');
    }

    for (final entry in result.writes.results) {
      logger.info('  [${_label(entry.outcome)}] ${entry.relativePath}');
      if (entry.backupPath != null && verbose) {
        logger.detail('    backup: ${entry.backupPath}');
      }
    }

    if (result.message != null) {
      logger.info(result.message!);
    }

    logger.info(
      'Summary: created=${result.writes.createdCount}, '
      'overwritten=${result.writes.overwrittenCount}, '
      'skipped=${result.writes.skippedCount}, '
      'dryRun=${result.writes.dryRun}',
    );

    return ExitCodes.success;
  }

  String _label(FileWriteOutcome outcome) {
    return switch (outcome) {
      FileWriteOutcome.created => 'create',
      FileWriteOutcome.overwritten => 'overwrite',
      FileWriteOutcome.backedUpAndOverwritten => 'backup+overwrite',
      FileWriteOutcome.skippedExists => 'skip',
      FileWriteOutcome.dryRun => 'dry-run',
    };
  }
}
