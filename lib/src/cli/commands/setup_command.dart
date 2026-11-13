import '../../core/exceptions.dart';
import '../../core/exit_codes.dart';
import '../../integrations/chico/chico_integration_service.dart';
import '../../integrations/chico/chico_packages.dart';
import '../command.dart';

/// `devkit setup chico` — configure Chico ecosystem integrations.
final class SetupCommand extends DevKitCommand {
  SetupCommand({
    required super.logger,
    required super.configService,
    required super.projectRootProvider,
    ChicoIntegrationService? integrationService,
  }) : _integrationService = integrationService {
    argParser.addFlag(
      'force',
      abbr: 'f',
      negatable: false,
      help: 'Overwrite bootstrap helpers.',
    );
  }

  final ChicoIntegrationService? _integrationService;

  @override
  String get name => 'setup';

  @override
  String get description => 'Set up Chico ecosystem integrations.';

  @override
  String get invocation => '${runner!.executableName} setup chico';

  @override
  Future<int> run() async {
    final rest = argResults!.rest;
    if (rest.isEmpty || rest.first.toLowerCase() != 'chico') {
      throw const InvalidUsageException(
        'Expected: setup chico',
        details: 'Example: devkit setup chico',
      );
    }

    final service =
        _integrationService ??
        ChicoIntegrationService(configService: configService);
    final result = await service.setup(
      projectRoot: projectRootProvider(),
      packages: ChicoPackageId.values,
      writeBootstrap: true,
      force: argResults!['force'] as bool,
    );

    logger.success('Chico setup complete.');
    if (result.addedPackages.isNotEmpty) {
      logger.info('Added: ${result.addedPackages.join(', ')}');
    }
    if (result.alreadyPresent.isNotEmpty) {
      logger.info('Already present: ${result.alreadyPresent.join(', ')}');
    }
    for (final doc in result.docs) {
      logger.info('- $doc');
    }
    if (result.bootstrapPath != null) {
      logger.info('Bootstrap helper: ${result.bootstrapPath}');
    }
    logger.info('Run: flutter pub get');
    return ExitCodes.success;
  }
}
