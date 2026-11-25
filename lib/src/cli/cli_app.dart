import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';

import '../config/config_service.dart';
import '../core/banner.dart';
import '../core/exceptions.dart';
import '../core/exit_codes.dart';
import '../core/logger.dart';
import '../core/version.dart';
import '../generators/registry.dart';
import '../project/flutter_cli.dart';
import '../quality/tool_runner.dart';
import 'commands/add_command.dart';
import 'commands/adopt_command.dart';
import 'commands/analyze_command.dart';
import 'commands/clean_command.dart';
import 'commands/config_command.dart';
import 'commands/create_command.dart';
import 'commands/doctor_command.dart';
import 'commands/format_command.dart';
import 'commands/generate_command.dart';
import 'commands/list_command.dart';
import 'commands/setup_command.dart';
import 'commands/test_command.dart';
import 'commands/upgrade_command.dart';

/// Top-level CLI application.
final class CliApp {
  CliApp({
    DevKitLogger? logger,
    ConfigService? configService,
    GeneratorRegistry? generatorRegistry,
    FlutterCli? flutterCli,
    ToolRunner? toolRunner,
    String? projectRoot,
    IOSink? stdoutSink,
    IOSink? stderrSink,
  }) : _logger = logger ?? DevKitLogger(),
       _configService = configService ?? ConfigService(),
       _generatorRegistry =
           generatorRegistry ?? createDefaultGeneratorRegistry(),
       _flutterCli = flutterCli,
       _toolRunner = toolRunner,
       _projectRoot = projectRoot,
       _stdout = stdoutSink ?? stdout,
       _stderr = stderrSink ?? stderr;

  final DevKitLogger _logger;
  final ConfigService _configService;
  final GeneratorRegistry _generatorRegistry;
  final FlutterCli? _flutterCli;
  final ToolRunner? _toolRunner;
  final String? _projectRoot;
  final IOSink _stdout;
  final IOSink _stderr;

  String get projectRoot => _projectRoot ?? Directory.current.path;

  /// Runs the CLI with [arguments]. Returns a process exit code.
  Future<int> run(List<String> arguments) async {
    final runner = _DevKitCommandRunner(
      stdoutSink: _stdout,
      onConfigureLogging: _configureLogging,
    );

    runner
      ..addCommand(
        DoctorCommand(
          logger: _logger,
          configService: _configService,
          projectRootProvider: () => projectRoot,
          toolRunner: _toolRunner,
        ),
      )
      ..addCommand(
        AnalyzeCommand(
          logger: _logger,
          configService: _configService,
          projectRootProvider: () => projectRoot,
          toolRunner: _toolRunner,
        ),
      )
      ..addCommand(
        FormatCommand(
          logger: _logger,
          configService: _configService,
          projectRootProvider: () => projectRoot,
          toolRunner: _toolRunner,
        ),
      )
      ..addCommand(
        TestCommand(
          logger: _logger,
          configService: _configService,
          projectRootProvider: () => projectRoot,
          toolRunner: _toolRunner,
        ),
      )
      ..addCommand(
        CleanCommand(
          logger: _logger,
          configService: _configService,
          projectRootProvider: () => projectRoot,
          toolRunner: _toolRunner,
        ),
      )
      ..addCommand(
        UpgradeCommand(
          logger: _logger,
          configService: _configService,
          projectRootProvider: () => projectRoot,
          toolRunner: _toolRunner,
        ),
      )
      ..addCommand(
        CreateCommand(
          logger: _logger,
          configService: _configService,
          projectRootProvider: () => projectRoot,
          flutterCli: _flutterCli,
        ),
      )
      ..addCommand(
        AdoptCommand(
          logger: _logger,
          configService: _configService,
          projectRootProvider: () => projectRoot,
        ),
      )
      ..addCommand(
        AddCommand(
          logger: _logger,
          configService: _configService,
          projectRootProvider: () => projectRoot,
        ),
      )
      ..addCommand(
        SetupCommand(
          logger: _logger,
          configService: _configService,
          projectRootProvider: () => projectRoot,
        ),
      )
      ..addCommand(
        GenerateCommand(
          logger: _logger,
          configService: _configService,
          projectRootProvider: () => projectRoot,
          registry: _generatorRegistry,
        ),
      )
      ..addCommand(
        ConfigCommand(
          logger: _logger,
          configService: _configService,
          projectRootProvider: () => projectRoot,
        ),
      )
      ..addCommand(
        ListCommand(
          logger: _logger,
          configService: _configService,
          projectRootProvider: () => projectRoot,
          registry: _generatorRegistry,
        ),
      );

    try {
      final result = await runner.run(arguments);
      return result ?? ExitCodes.success;
    } on DevKitException catch (error) {
      _logger.err(error.message);
      if (error.details != null) {
        _logger.info(error.details!);
      }
      return error.exitCode;
    } on UsageException catch (error) {
      _logger.err(error.message);
      _stderr.writeln(error.usage);
      return ExitCodes.usage;
    } catch (error, stackTrace) {
      _logger.err('Unexpected error: $error');
      if (_logger.raw.level == Level.verbose) {
        _stderr.writeln(stackTrace);
      }
      return ExitCodes.failure;
    }
  }

  void _configureLogging({required bool verbose, required bool quiet}) {
    if (quiet) {
      _logger.setLevel(Level.error);
    } else if (verbose) {
      _logger.setLevel(Level.verbose);
    } else {
      _logger.setLevel(Level.info);
    }
  }
}

/// Command runner with banner + `--version` handling.
final class _DevKitCommandRunner extends CommandRunner<int> {
  _DevKitCommandRunner({
    required IOSink stdoutSink,
    required void Function({required bool verbose, required bool quiet})
    onConfigureLogging,
  }) : _stdout = stdoutSink,
       _onConfigureLogging = onConfigureLogging,
       super(
         executableName,
         '$productName — professional Flutter development toolkit',
       ) {
    argParser
      ..addFlag(
        'version',
        abbr: 'V',
        negatable: false,
        help: 'Print the DevKit version.',
      )
      ..addFlag('verbose', negatable: false, help: 'Enable verbose logging.')
      ..addFlag('quiet', negatable: false, help: 'Suppress non-error output.');
  }

  final IOSink _stdout;
  final void Function({required bool verbose, required bool quiet})
  _onConfigureLogging;

  @override
  Future<int?> run(Iterable<String> args) async {
    final argResults = parse(args);
    _onConfigureLogging(
      verbose: argResults['verbose'] as bool,
      quiet: argResults['quiet'] as bool,
    );

    if (argResults['version'] as bool) {
      _stdout.writeln(packageVersion);
      return ExitCodes.success;
    }

    return runCommand(argResults);
  }

  @override
  void printUsage() {
    _stdout.writeln(buildBanner());
    _stdout.writeln(usage);
  }
}
