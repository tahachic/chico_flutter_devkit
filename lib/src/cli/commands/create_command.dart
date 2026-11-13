import 'dart:io';

import 'package:path/path.dart' as p;

import '../../config/models.dart';
import '../../core/exceptions.dart';
import '../../core/exit_codes.dart';
import '../../naming/name_converter.dart';
import '../../project/flutter_cli.dart';
import '../../project/project_factory.dart';
import '../../project/project_options.dart';
import '../command.dart';

/// `devkit create <name>` — create a Flutter application.
final class CreateCommand extends DevKitCommand {
  CreateCommand({
    required super.logger,
    required super.configService,
    required super.projectRootProvider,
    FlutterCli? flutterCli,
    ProjectFactory? projectFactory,
  }) : _flutterCli = flutterCli,
       _projectFactory = projectFactory {
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
        allowed: const ['go_router'],
        defaultsTo: Routing.goRouter.yamlValue,
        help: 'Routing solution (go_router only in this release).',
      )
      ..addOption(
        'di',
        allowed: DependencyInjection.values.map((e) => e.yamlValue),
        defaultsTo: DependencyInjection.getIt.yamlValue,
        help:
            'Dependency injection approach '
            '(get_it fully scaffolded; riverpod/manual are composition-root stubs).',
      )
      ..addOption(
        'org',
        defaultsTo: 'com.example',
        help: 'Organization / reverse-DNS id.',
      )
      ..addOption(
        'output',
        abbr: 'o',
        help: 'Output directory (defaults to ./<name>).',
      )
      ..addFlag(
        'interactive',
        defaultsTo: true,
        help: 'Prompt for options when flags are omitted.',
      )
      ..addFlag('chico-ui', defaultsTo: true, help: 'Enable chico_ui.')
      ..addFlag('chico-kit', defaultsTo: true, help: 'Enable chico_kit.')
      ..addFlag(
        'chico-services',
        defaultsTo: true,
        help: 'Enable chico_services.',
      )
      ..addFlag('localization', defaultsTo: true, help: 'Enable localization.')
      ..addFlag('dark-mode', defaultsTo: true, help: 'Enable dark theme.')
      ..addFlag('logging', defaultsTo: true, help: 'Enable logging helper.')
      ..addFlag(
        'error-handling',
        defaultsTo: true,
        help: 'Enable error-handling helper.',
      )
      ..addFlag(
        'example-feature',
        defaultsTo: true,
        help: 'Generate an example feature.',
      )
      ..addFlag(
        'pub-get',
        defaultsTo: true,
        help: 'Run flutter pub get after creation.',
      );
  }

  final FlutterCli? _flutterCli;
  final ProjectFactory? _projectFactory;

  @override
  String get name => 'create';

  @override
  String get description =>
      'Create a new Flutter application from DevKit templates.';

  @override
  String get invocation =>
      '${runner!.executableName} create <name> [arguments]';

  @override
  Future<int> run() async {
    final rest = argResults!.rest;
    if (rest.isEmpty) {
      throw const InvalidUsageException(
        'Missing application name.',
        details:
            'Example: devkit create shop_app --architecture clean --state bloc',
      );
    }

    final rawName = rest.first;
    final name = NameConverter.parse(rawName).snakeCase;
    final interactive = argResults!['interactive'] as bool;

    var architecture = Architecture.parse(
      argResults!['architecture'] as String,
    );
    var state = StateManagement.parse(argResults!['state'] as String);
    var routing = Routing.parse(argResults!['routing'] as String);
    var di = DependencyInjection.parse(argResults!['di'] as String);
    var org = argResults!['org'] as String;

    if (routing != Routing.goRouter) {
      throw const InvalidUsageException(
        'Only go_router routing is supported in this release.',
        details: 'Pass --routing go_router (the default).',
      );
    }

    if (interactive && stdin.hasTerminal) {
      architecture = _chooseEnum(
        'Architecture',
        Architecture.values,
        architecture,
        (value) => value.yamlValue,
      );
      state = _chooseEnum(
        'State management',
        StateManagement.values,
        state,
        (value) => value.yamlValue,
      );
      routing = _chooseEnum(
        'Routing',
        const [Routing.goRouter],
        routing,
        (value) => value.yamlValue,
      );
      di = _chooseEnum(
        'Dependency injection',
        DependencyInjection.values,
        di,
        (value) => value.yamlValue,
      );
      final orgAnswer = logger.raw.prompt('Organization', defaultValue: org);
      if (orgAnswer.trim().isNotEmpty) org = orgAnswer.trim();
    }

    final output =
        argResults!['output'] as String? ?? p.join(projectRootProvider(), name);

    final flutterCli = _flutterCli ?? ProcessFlutterCli();
    final factory =
        _projectFactory ??
        ProjectFactory(
          configService: configService,
          flutterCli: flutterCli,
          runPubGet: argResults!['pub-get'] as bool,
        );

    final progress = logger.progress('Creating $name');
    try {
      final result = await factory.create(
        ProjectCreateOptions(
          name: name,
          organization: org,
          architecture: architecture,
          stateManagement: state,
          routing: routing,
          dependencyInjection: di,
          enableChicoUi: argResults!['chico-ui'] as bool,
          enableChicoKit: argResults!['chico-kit'] as bool,
          enableChicoServices: argResults!['chico-services'] as bool,
          enableLocalization: argResults!['localization'] as bool,
          enableDarkMode: argResults!['dark-mode'] as bool,
          enableLogging: argResults!['logging'] as bool,
          enableErrorHandling: argResults!['error-handling'] as bool,
          generateExampleFeature: argResults!['example-feature'] as bool,
          outputDirectory: output,
        ),
      );
      progress.complete('Created ${result.projectPath}');
      logger.info('Files overlayed: ${result.writtenFiles.length}');
      if (result.chicoPackages.isNotEmpty) {
        logger.info('Chico packages: ${result.chicoPackages.join(', ')}');
      }
      if (argResults!['localization'] as bool) {
        logger.info(
          'Localization: lightweight scaffold only '
          '(not flutter gen-l10n).',
        );
      }
      if (di != DependencyInjection.getIt) {
        logger.info(
          'DI ($di): composition-root stub — wire providers/services manually.',
        );
      }
      logger.success('Next: cd ${result.projectPath} && flutter run');
      return ExitCodes.success;
    } catch (error) {
      progress.fail('Create failed');
      rethrow;
    }
  }

  T _chooseEnum<T>(
    String label,
    List<T> values,
    T current,
    String Function(T) labelOf,
  ) {
    return logger.raw.chooseOne<T>(
      label,
      choices: values,
      display: labelOf,
      defaultValue: current,
    );
  }
}
