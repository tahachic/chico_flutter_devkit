import 'dart:convert';

import '../../core/exit_codes.dart';
import '../../quality/quality_service.dart';
import '../../quality/tool_runner.dart';
import '../command.dart';

/// `devkit format` — format Dart sources.
final class FormatCommand extends DevKitCommand {
  FormatCommand({
    required super.logger,
    required super.configService,
    required super.projectRootProvider,
    ToolRunner? toolRunner,
  }) : _toolRunner = toolRunner {
    argParser
      ..addFlag('json', negatable: false, help: 'Emit a JSON summary.')
      ..addFlag(
        'set-exit-if-changed',
        negatable: false,
        help: 'Exit non-zero if formatting would change files.',
      );
  }

  final ToolRunner? _toolRunner;

  @override
  String get name => 'format';

  @override
  String get description => 'Format Dart source files.';

  @override
  Future<int> run() async {
    final service = QualityService(
      toolRunner: _toolRunner ?? ProcessToolRunner(),
    );
    final progress = logger.progress('Formatting');
    final result = await service.format(
      projectRootProvider(),
      setExitIfChanged: argResults!['set-exit-if-changed'] as bool,
    );
    if (result.success) {
      progress.complete('Format complete');
    } else {
      progress.fail('Format failed');
    }

    if (argResults!['json'] as bool) {
      logger.info(
        jsonEncode({
          'success': result.success,
          'exitCode': result.exitCode,
          'stdout': result.stdout,
          'stderr': result.stderr,
        }),
      );
    } else if (result.stdout.trim().isNotEmpty) {
      logger.info(result.stdout.trim());
    }

    return result.success ? ExitCodes.success : ExitCodes.failure;
  }
}
