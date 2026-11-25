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
        allowed: Routing.values.map((e) => e.yamlValue).toList(growable: false),
        defaultsTo: Routing.goRouter.yamlValue,
        help: 'Routing: go_router (default) or navigator (Navigator 1.0).',
      )
      ..addOption(
        'di',
        allowed: DependencyInjection.values.map((e) => e.yamlValue),
        defaultsTo: DependencyInjection.getIt.yamlValue,
        help:
            'Dependency injection approach '
            'Composition root: get_it modules, Riverpod container, or manual factories.',
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
      ..addFlag(
        'chico',
        defaultsTo: false,
        help:
            'Opt in to the full Chico stack (ui + kit + services). '
            'Off by default — Material-first create; use setup/add later.',
      )
      ..addFlag(
        'chico-ui',
        defaultsTo: false,
        help: 'Enable chico_ui (also implied by --chico).',
      )
      ..addFlag(
        'chico-kit',
        defaultsTo: false,
        help: 'Enable chico_kit (also implied by --chico).',
      )
      ..addFlag(
        'chico-services',
        defaultsTo: false,
        help: 'Enable chico_services (also implied by --chico).',
      )
      ..addFlag(
        'localization',
        defaultsTo: true,
        help: 'Enable flutter gen-l10n (ARB + l10n.yaml).',
      )
      ..addMultiOption(
        'locales',
        defaultsTo: const ['en'],
        help:
            'Locales for gen-l10n ARB files (e.g. --locales en --locales fr). '
            'Ignored when --no-localization.',
      )
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
      )
      ..addOption(
        'platforms',
        defaultsTo: 'android,ios,web',
        help:
            'Comma-separated Flutter platforms '
            '(e.g. android,ios,web,windows,macos,linux).',
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
        Routing.values,
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

    var enableChicoUi = argResults!['chico-ui'] as bool;
    var enableChicoKit = argResults!['chico-kit'] as bool;
    var enableChicoServices = argResults!['chico-services'] as bool;
    if (argResults!['chico'] as bool) {
      enableChicoUi = true;
      enableChicoKit = true;
      enableChicoServices = true;
      // Allow explicit --no-chico-* to peel packages off the full stack.
      if (argResults!.wasParsed('chico-ui')) {
        enableChicoUi = argResults!['chico-ui'] as bool;
      }
      if (argResults!.wasParsed('chico-kit')) {
        enableChicoKit = argResults!['chico-kit'] as bool;
      }
      if (argResults!.wasParsed('chico-services')) {
        enableChicoServices = argResults!['chico-services'] as bool;
      }
    }

    if (interactive &&
        stdin.hasTerminal &&
        !argResults!.wasParsed('chico') &&
        !argResults!.wasParsed('chico-ui') &&
        !argResults!.wasParsed('chico-kit') &&
        !argResults!.wasParsed('chico-services')) {
      final wantChico = logger.raw.confirm(
        'Include Chico packages (ui / kit / services)?',
        defaultValue: false,
      );
      if (wantChico) {
        enableChicoUi = true;
        enableChicoKit = true;
        enableChicoServices = true;
      }
    }

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
          enableChicoUi: enableChicoUi,
          enableChicoKit: enableChicoKit,
          enableChicoServices: enableChicoServices,
          enableLocalization: argResults!['localization'] as bool,
          languages: (argResults!['locales'] as List<String>)
              .expand((e) => e.split(','))
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList(growable: false),
          enableDarkMode: argResults!['dark-mode'] as bool,
          enableLogging: argResults!['logging'] as bool,
          enableErrorHandling: argResults!['error-handling'] as bool,
          generateExampleFeature: argResults!['example-feature'] as bool,
          outputDirectory: output,
          platforms: (argResults!['platforms'] as String)
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .join(','),
        ),
      );
      progress.complete('Created ${result.projectPath}');
      logger.info('Files overlayed: ${result.writtenFiles.length}');
      if (result.chicoPackages.isNotEmpty) {
        logger.info('Chico packages: ${result.chicoPackages.join(', ')}');
      } else {
        logger.info(
          'Material-first app (no Chico). '
          'Add later with: devkit setup chico',
        );
      }
      if (argResults!['localization'] as bool) {
        final locales = (argResults!['locales'] as List<String>).join(', ');
        logger.info(
          'Localization: flutter gen-l10n '
          '(l10n.yaml + lib/l10n ARB; locales: $locales).',
        );
      }
      logger.info(switch (di) {
        DependencyInjection.getIt =>
          'DI: get_it (core_module + feature_registrations).',
        DependencyInjection.riverpod =>
          'DI: Riverpod (appContainer + UncontrolledProviderScope).',
        DependencyInjection.manual =>
          'DI: manual (AppServices + FeatureFactories).',
      });
      logger.info(switch (routing) {
        Routing.goRouter => 'Routing: go_router.',
        Routing.navigator => 'Routing: Navigator 1.0 (named routes).',
      });
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
