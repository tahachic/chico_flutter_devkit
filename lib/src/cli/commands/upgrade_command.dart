import 'dart:convert';

import '../../core/exit_codes.dart';
import '../../quality/quality_service.dart';
import '../../quality/tool_runner.dart';
import '../command.dart';

/// `devkit upgrade` — upgrade DevKit-managed Chico dependencies.
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
        help: 'Show planned upgrades without modifying pubspec.',
      )
      ..addFlag('json', negatable: false, help: 'Emit a JSON summary.');
  }

  final ToolRunner? _toolRunner;

  @override
  String get name => 'upgrade';

  @override
  String get description =>
      'Upgrade DevKit-managed Chico dependencies to current defaults.';

  @override
  Future<int> run() async {
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
