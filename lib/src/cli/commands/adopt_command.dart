import '../../config/models.dart';
import '../../core/exceptions.dart';
import '../../core/exit_codes.dart';
import '../../project/adopt_service.dart';
import '../command.dart';

/// `devkit adopt` — bring an existing Flutter app into the DevKit matrix.
final class AdoptCommand extends DevKitCommand {
  AdoptCommand({
    required super.logger,
    required super.configService,
    required super.projectRootProvider,
    AdoptService? adoptService,
  }) : _adoptService = adoptService {
    argParser
      ..addOption(
        'architecture',
        allowed: Architecture.values.map((e) => e.yamlValue),
        defaultsTo: Architecture.clean.yamlValue,
        help: 'Application architecture.',
      )
      ..addOption(
        'state',
        allowed: StateManagement.values.map((e) => e.yamlValue),
        defaultsTo: StateManagement.bloc.yamlValue,
        help: 'State management solution.',
      )
      ..addOption(
        'routing',
        allowed: Routing.values.map((e) => e.yamlValue),
        defaultsTo: Routing.goRouter.yamlValue,
        help: 'Routing: go_router (default) or navigator.',
      )
      ..addOption(
        'di',
        allowed: DependencyInjection.values.map((e) => e.yamlValue),
        defaultsTo: DependencyInjection.getIt.yamlValue,
        help: 'Dependency injection approach.',
      )
      ..addFlag(
        'force',
        abbr: 'f',
        negatable: false,
        help: 'Overwrite existing .chico/devkit.yaml.',
      )
      ..addFlag('dry-run', negatable: false, help: 'Plan only; write nothing.');
  }

  final AdoptService? _adoptService;

  @override
  String get name => 'adopt';

  @override
  String get description =>
      'Adopt an existing Flutter app into the DevKit stack matrix.';

  @override
  String get invocation =>
      '${runner!.executableName} adopt [--architecture clean] [--state bloc] '
      '[--routing go_router] [--di get_it]';

  @override
  Future<int> run() async {
    final root = projectRootProvider();
    final service = _adoptService ?? AdoptService(configService: configService);

    try {
      final result = await service.adopt(
        projectRoot: root,
        architecture: Architecture.parse(argResults!['architecture'] as String),
        state: StateManagement.parse(argResults!['state'] as String),
        routing: Routing.parse(argResults!['routing'] as String),
        di: DependencyInjection.parse(argResults!['di'] as String),
        forceConfig: argResults!['force'] as bool,
        dryRun: argResults!['dry-run'] as bool,
      );
      logger.success(result.message);
      return ExitCodes.success;
    } on ConfigException catch (error) {
      throw InvalidUsageException(error.message, details: error.details);
    }
  }
}
