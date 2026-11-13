import 'dart:convert';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../../config/config_paths.dart';
import '../../config/config_service.dart';
import '../../core/exceptions.dart';
import '../../core/exit_codes.dart';
import '../../core/logger.dart';
import '../command.dart';

/// `devkit config` — inspect and manage DevKit configuration.
final class ConfigCommand extends Command<int> {
  ConfigCommand({
    required DevKitLogger logger,
    required ConfigService configService,
    required String Function() projectRootProvider,
  }) {
    addSubcommand(
      _ConfigShowCommand(
        logger: logger,
        configService: configService,
        projectRootProvider: projectRootProvider,
      ),
    );
    addSubcommand(
      _ConfigInitCommand(
        logger: logger,
        configService: configService,
        projectRootProvider: projectRootProvider,
      ),
    );
    addSubcommand(
      _ConfigSetCommand(
        logger: logger,
        configService: configService,
        projectRootProvider: projectRootProvider,
      ),
    );
    addSubcommand(
      _ConfigPathCommand(
        logger: logger,
        configService: configService,
        projectRootProvider: projectRootProvider,
      ),
    );
  }

  @override
  String get name => 'config';

  @override
  String get description =>
      'Show, initialize, and update DevKit configuration.';
}

final class _ConfigShowCommand extends DevKitCommand {
  _ConfigShowCommand({
    required super.logger,
    required super.configService,
    required super.projectRootProvider,
  }) {
    argParser.addFlag(
      'json',
      help: 'Print configuration as JSON.',
      negatable: false,
    );
  }

  @override
  String get name => 'show';

  @override
  String get description => 'Show the resolved DevKit configuration.';

  @override
  Future<int> run() async {
    final context = createContext();
    final resolved = context.configService.resolve(
      projectRoot: context.projectRoot,
    );

    if (argResults!['json'] as bool) {
      logger.info(jsonEncode(resolved.config.toYamlMap()));
    } else {
      logger.info('Resolved configuration');
      logger.info('Project root : ${resolved.projectRoot}');
      logger.info(
        'Project file : ${resolved.projectConfigPath}'
        '${resolved.projectConfigExists ? '' : ' (missing)'}',
      );
      logger.info(
        'User file    : ${resolved.userConfigPath}'
        '${resolved.userConfigExists ? '' : ' (missing)'}',
      );
      logger.info('');
      logger.info(context.configService.serialize(resolved.config));
    }
    return ExitCodes.success;
  }
}

final class _ConfigInitCommand extends DevKitCommand {
  _ConfigInitCommand({
    required super.logger,
    required super.configService,
    required super.projectRootProvider,
  }) {
    argParser
      ..addFlag(
        'force',
        abbr: 'f',
        help: 'Overwrite an existing project configuration file.',
        negatable: false,
      )
      ..addOption('name', help: 'Project name written into the configuration.')
      ..addOption(
        'organization',
        help: 'Organization / reverse-DNS package id.',
      );
  }

  @override
  String get name => 'init';

  @override
  String get description =>
      'Create `.chico/devkit.yaml` in the current project.';

  @override
  Future<int> run() async {
    final context = createContext();
    final name = argResults!['name'] as String?;
    final organization = argResults!['organization'] as String?;
    final force = argResults!['force'] as bool;

    final hintName =
        name ??
        p
            .basename(context.projectRoot)
            .replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_')
            .toLowerCase();

    final defaults = context.configService
        .resolve(projectRoot: context.projectRoot, projectNameHint: hintName)
        .config;

    final config = defaults.copyWith(
      project: defaults.project.copyWith(
        name: hintName,
        organization: organization,
      ),
    );

    final path = await context.configService.initProjectConfig(
      projectRoot: context.projectRoot,
      config: config,
      force: force,
    );

    logger.success('Created configuration at $path');
    return ExitCodes.success;
  }
}

final class _ConfigSetCommand extends DevKitCommand {
  _ConfigSetCommand({
    required super.logger,
    required super.configService,
    required super.projectRootProvider,
  });

  @override
  String get name => 'set';

  @override
  String get description =>
      'Set a dotted configuration key in the project config file.';

  @override
  String get invocation => '${runner!.executableName} config set <key> <value>';

  @override
  Future<int> run() async {
    final rest = argResults!.rest;
    if (rest.length != 2) {
      throw const InvalidUsageException(
        'Expected exactly two arguments: <key> <value>.',
        details: 'Example: devkit config set project.architecture clean',
      );
    }

    final context = createContext();
    final updated = await context.configService.setProjectValue(
      projectRoot: context.projectRoot,
      key: rest[0],
      value: rest[1],
    );

    logger.success('Updated ${rest[0]} = ${rest[1]}');
    if (verbose) {
      logger.detail(context.configService.serialize(updated));
    }
    return ExitCodes.success;
  }
}

final class _ConfigPathCommand extends DevKitCommand {
  _ConfigPathCommand({
    required super.logger,
    required super.configService,
    required super.projectRootProvider,
  }) {
    argParser.addFlag(
      'user',
      help: 'Print the user-level configuration path instead.',
      negatable: false,
    );
  }

  @override
  String get name => 'path';

  @override
  String get description => 'Print configuration file paths.';

  @override
  Future<int> run() async {
    final context = createContext();
    final showUser = argResults!['user'] as bool;
    if (showUser) {
      logger.info(
        context.configService
            .resolve(projectRoot: context.projectRoot)
            .userConfigPath,
      );
    } else {
      logger.info(ConfigPaths.projectConfigFile(context.projectRoot));
    }
    return ExitCodes.success;
  }
}
