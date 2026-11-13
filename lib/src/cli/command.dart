import 'package:args/args.dart';
import 'package:args/command_runner.dart';

import '../config/config_service.dart';
import '../core/logger.dart';

/// Shared context available to every DevKit command.
final class CommandContext {
  CommandContext({
    required this.logger,
    required this.configService,
    required this.projectRoot,
    required this.verbose,
    required this.rest,
  });

  final DevKitLogger logger;
  final ConfigService configService;
  final String projectRoot;
  final bool verbose;
  final ArgResults rest;
}

/// Base command with shared DevKit helpers.
abstract class DevKitCommand extends Command<int> {
  DevKitCommand({
    required this.logger,
    required this.configService,
    required this.projectRootProvider,
  });

  final DevKitLogger logger;
  final ConfigService configService;
  final String Function() projectRootProvider;

  bool get verbose {
    final global = globalResults;
    if (global == null) return false;
    return global['verbose'] as bool? ?? false;
  }

  CommandContext createContext() {
    return CommandContext(
      logger: logger,
      configService: configService,
      projectRoot: projectRootProvider(),
      verbose: verbose,
      rest: argResults!,
    );
  }
}
