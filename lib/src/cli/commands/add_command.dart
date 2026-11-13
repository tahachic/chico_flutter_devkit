import '../../core/exceptions.dart';
import '../../core/exit_codes.dart';
import '../../integrations/chico/chico_integration_service.dart';
import '../../integrations/chico/chico_packages.dart';
import '../command.dart';

/// `devkit add <package>` — add a Chico package to the current project.
final class AddCommand extends DevKitCommand {
  AddCommand({
    required super.logger,
    required super.configService,
    required super.projectRootProvider,
    ChicoIntegrationService? integrationService,
  }) : _integrationService = integrationService {
    argParser
      ..addOption('version', help: 'Pub version constraint override.')
      ..addFlag(
        'bootstrap',
        defaultsTo: false,
        help: 'Also write lib/core/chico_bootstrap.dart',
      )
      ..addFlag(
        'force',
        abbr: 'f',
        negatable: false,
        help: 'Overwrite bootstrap.',
      );
  }

  final ChicoIntegrationService? _integrationService;

  @override
  String get name => 'add';

  @override
  String get description => 'Add a Chico package integration.';

  @override
  String get invocation =>
      '${runner!.executableName} add <chico_ui|chico_kit|chico_services>';

  @override
  Future<int> run() async {
    final rest = argResults!.rest;
    if (rest.isEmpty) {
      throw const InvalidUsageException(
        'Missing package name.',
        details: 'Example: devkit add chico_ui',
      );
    }

    late final ChicoPackageId package;
    try {
      package = ChicoPackageId.parse(rest.first);
    } on FormatException catch (error) {
      throw InvalidUsageException(error.message);
    }

    final service =
        _integrationService ??
        ChicoIntegrationService(configService: configService);
    final result = await service.addPackage(
      projectRoot: projectRootProvider(),
      package: package,
      versionConstraint: argResults!['version'] as String?,
      writeBootstrap: argResults!['bootstrap'] as bool,
      force: argResults!['force'] as bool,
    );

    if (result.addedPackages.isEmpty) {
      logger.info('${package.packageName} already present.');
    } else {
      logger.success('Added: ${result.addedPackages.join(', ')}');
    }
    for (final doc in result.docs) {
      logger.info(doc);
    }
    if (result.bootstrapPath != null) {
      logger.info('Bootstrap: ${result.bootstrapPath}');
    }
    logger.info('Run: flutter pub get');
    return ExitCodes.success;
  }
}
