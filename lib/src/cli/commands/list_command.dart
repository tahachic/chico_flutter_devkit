import '../../core/exit_codes.dart';
import '../../generators/registry.dart';
import '../command.dart';

/// `devkit list` — list available commands or registered generators.
final class ListCommand extends DevKitCommand {
  ListCommand({
    required super.logger,
    required super.configService,
    required super.projectRootProvider,
    required this.registry,
  }) {
    argParser.addOption(
      'type',
      allowed: ['commands', 'generators'],
      defaultsTo: 'commands',
      help: 'What to list.',
    );
  }

  final GeneratorRegistry registry;

  @override
  String get name => 'list';

  @override
  String get description => 'List available commands or generators.';

  @override
  Future<int> run() async {
    final type = argResults!['type'] as String;
    if (type == 'generators') {
      logger.info('Registered generators:');
      for (final generator in registry.all) {
        logger.info('  - ${generator.name}: ${generator.description}');
      }
      return ExitCodes.success;
    }

    logger.info('Commands:');
    for (final item in const [
      'create      Create a Flutter application',
      'generate   Run code generators',
      'doctor     Diagnose the current project',
      'analyze    Run static analysis',
      'format     Format Dart sources',
      'test       Run project tests',
      'clean      Clean build artifacts',
      'upgrade    Upgrade managed Chico dependencies',
      'config     Manage DevKit configuration',
      'list       List commands or generators',
      'add        Add a Chico package',
      'setup      Configure Chico integrations',
    ]) {
      logger.info('  $item');
    }
    return ExitCodes.success;
  }
}
