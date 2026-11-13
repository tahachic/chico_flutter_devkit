import 'dart:convert';

import '../../core/exit_codes.dart';
import '../../quality/quality_service.dart';
import '../../quality/tool_runner.dart';
import '../command.dart';

/// `devkit test` — run Flutter tests.
final class TestCommand extends DevKitCommand {
  TestCommand({
    required super.logger,
    required super.configService,
    required super.projectRootProvider,
    ToolRunner? toolRunner,
  }) : _toolRunner = toolRunner {
    argParser
      ..addFlag('json', negatable: false, help: 'Emit a JSON summary.')
      ..addFlag('coverage', negatable: false, help: 'Collect coverage.');
  }

  final ToolRunner? _toolRunner;

  @override
  String get name => 'test';

  @override
  String get description => 'Run project tests.';

  @override
  Future<int> run() async {
    final service = QualityService(
      toolRunner: _toolRunner ?? ProcessToolRunner(),
    );
    final progress = logger.progress('Testing');
    final result = await service.test(
      projectRootProvider(),
      coverage: argResults!['coverage'] as bool,
    );
    if (result.success) {
      progress.complete('Tests passed');
    } else {
      progress.fail('Tests failed');
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
    } else {
      if (result.stdout.trim().isNotEmpty) logger.info(result.stdout.trim());
      if (result.stderr.trim().isNotEmpty) logger.err(result.stderr.trim());
    }

    return result.success ? ExitCodes.success : ExitCodes.failure;
  }
}
