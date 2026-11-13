/// Chico Flutter DevKit — public library surface.
///
/// The CLI entrypoint is `bin/devkit.dart`. Most consumers should install via:
/// `dart pub global activate chico_flutter_devkit` and run `devkit`.
library;

export 'src/cli/cli_app.dart';
export 'src/config/config_paths.dart';
export 'src/config/config_service.dart';
export 'src/config/defaults.dart';
export 'src/config/models.dart';
export 'src/config/overrides.dart';
export 'src/core/exceptions.dart';
export 'src/core/exit_codes.dart';
export 'src/core/logger.dart';
export 'src/core/version.dart';
export 'src/fs/safe_file_system.dart';
export 'src/fs/write_plan.dart';
export 'src/generators/context.dart';
export 'src/generators/generator.dart';
export 'src/generators/registry.dart';
export 'src/generators/result.dart';
export 'src/generators/runner.dart';
export 'src/integrations/chico/chico_packages.dart';
export 'src/naming/name_converter.dart';
export 'src/project/flutter_cli.dart';
export 'src/project/project_factory.dart';
export 'src/project/project_options.dart';
export 'src/template/catalog.dart';
export 'src/template/descriptor.dart';
export 'src/template/engine.dart';
export 'src/template/package_templates.dart';
