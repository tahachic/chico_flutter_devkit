import '../../core/exit_codes.dart';
import '../../quality/quality_service.dart';
import '../../quality/tool_runner.dart';
import '../command.dart';

/// `devkit clean` — clean build artifacts.
final class CleanCommand extends DevKitCommand {
  CleanCommand({
    required super.logger,
    required super.configService,
    required super.projectRootProvider,
    ToolRunner? toolRunner,
  }) : _toolRunner = toolRunner;

  final ToolRunner? _toolRunner;

  @override
  String get name => 'clean';

  @override
  String get description => 'Clean build artifacts safely.';

  @override
  Future<int> run() async {
    final service = QualityService(
      toolRunner: _toolRunner ?? ProcessToolRunner(),
    );
    final progress = logger.progress('Cleaning');
    final result = await service.clean(projectRootProvider());
    if (result.success) {
      progress.complete('Clean complete');
      return ExitCodes.success;
    }
    progress.fail('Clean failed');
    if (result.stderr.trim().isNotEmpty) logger.err(result.stderr.trim());
    return ExitCodes.failure;
  }
}
