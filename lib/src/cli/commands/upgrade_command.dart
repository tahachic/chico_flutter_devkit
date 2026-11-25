import 'dart:convert';

import '../../core/exit_codes.dart';
import '../../project/upgrade_scaffolds_service.dart';
import '../../quality/quality_service.dart';
import '../../quality/tool_runner.dart';
import '../command.dart';

/// `devkit upgrade` — Chico deps, or `upgrade scaffolds` for DevKit anchors.
final class UpgradeCommand extends DevKitCommand {
  UpgradeCommand({
    required super.logger,
    required super.configService,
    required super.projectRootProvider,
    ToolRunner? toolRunner,
  }) : _toolRunner = toolRunner {
    argParser
      ..addFlag(
        'dry-run',
        negatable: false,
        help: 'Show planned upgrades without writing.',
      )
      ..addFlag(
        'force',
        abbr: 'f',
        negatable: false,
        help: 'Allow scaffold refresh even when files drifted.',
      )
      ..addFlag('json', negatable: false, help: 'Emit a JSON summary.');
  }

  final ToolRunner? _toolRunner;

  @override
  String get name => 'upgrade';

  @override
  String get description =>
      'Upgrade Chico deps, or refresh DevKit scaffolds '
      '(`upgrade scaffolds`).';

  @override
  String get invocation =>
      '${runner!.executableName} upgrade [scaffolds] [arguments]';

  @override
  Future<int> run() async {
    final rest = argResults!.rest;
    if (rest.isNotEmpty && rest.first.toLowerCase() == 'scaffolds') {
      final result = await UpgradeScaffoldsService().run(
        projectRoot: projectRootProvider(),
        dryRun: argResults!['dry-run'] as bool,
        force: argResults!['force'] as bool,
      );
      if (argResults!['json'] as bool) {
        logger.info(
          jsonEncode({
            'dryRun': result.dryRun,
            'refreshed': result.refreshed,
            'skippedDrift': result.skippedDrift,
          }),
        );
      } else {
        logger.success(result.message);
      }
      return ExitCodes.success;
    }

    final service = QualityService(
      toolRunner: _toolRunner ?? ProcessToolRunner(),
    );
    final dryRun = argResults!['dry-run'] as bool;
    final result = await service.upgrade(projectRootProvider(), dryRun: dryRun);

    if (argResults!['json'] as bool) {
      logger.info(
        jsonEncode({
          'dryRun': result.dryRun,
          'planned': result.planned,
          'applied': result.applied,
          'pubGetExitCode': result.pubGet?.exitCode,
        }),
      );
    } else if (result.planned.isEmpty) {
      logger.success('Chico dependencies already match DevKit defaults.');
    } else if (dryRun) {
      logger.info('Planned upgrades:');
      for (final item in result.planned) {
        logger.info('  - $item');
      }
    } else {
      logger.success('Updated: ${result.applied.join(', ')}');
      if (result.pubGet != null && !result.pubGet!.success) {
        logger.err('flutter pub get failed after upgrade.');
        return ExitCodes.failure;
      }
    }

    return ExitCodes.success;
  }
}
