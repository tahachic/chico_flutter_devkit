import 'dart:convert';

import '../../core/exit_codes.dart';
import '../../quality/quality_service.dart';
import '../../quality/tool_runner.dart';
import '../command.dart';

/// `devkit analyze` — run Flutter analyzer.
final class AnalyzeCommand extends DevKitCommand {
  AnalyzeCommand({
    required super.logger,
    required super.configService,
    required super.projectRootProvider,
    ToolRunner? toolRunner,
  }) : _toolRunner = toolRunner {
    argParser
      ..addFlag('json', negatable: false, help: 'Emit a JSON summary.')
      ..addFlag(
        'fatal-infos',
        negatable: false,
        help: 'Fail when analyzer infos are present.',
      );
  }

  final ToolRunner? _toolRunner;

  @override
  String get name => 'analyze';

  @override
  String get description => 'Run Dart/Flutter static analysis.';

  @override
  Future<int> run() async {
    final service = QualityService(
      toolRunner: _toolRunner ?? ProcessToolRunner(),
    );
    final progress = logger.progress('Analyzing');
    final result = await service.analyze(
      projectRootProvider(),
      fatalInfos: argResults!['fatal-infos'] as bool,
    );
    if (result.success) {
      progress.complete('Analyze passed');
    } else {
      progress.fail('Analyze failed');
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
