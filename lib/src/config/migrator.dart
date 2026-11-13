import '../core/exceptions.dart';
import 'defaults.dart';
import 'models.dart';

/// Migrates configuration maps between schema versions.
final class DevKitConfigMigrator {
  const DevKitConfigMigrator();

  /// Ensures [config] matches [currentSchemaVersion].
  DevKitConfig migrate(DevKitConfig config) {
    var current = config;

    if (current.schemaVersion > currentSchemaVersion) {
      throw ConfigException(
        'Configuration schemaVersion ${current.schemaVersion} is newer than '
        'this DevKit build supports ($currentSchemaVersion). '
        'Upgrade DevKit or lower schemaVersion.',
      );
    }

    while (current.schemaVersion < currentSchemaVersion) {
      current = _migrateOneStep(current);
    }

    return current;
  }

  DevKitConfig _migrateOneStep(DevKitConfig config) {
    // Schema v1 is the initial version. Future migrations go here:
    // switch (config.schemaVersion) { case 1: return migrateV1ToV2(config); }
    throw ConfigException(
      'No migration path from schemaVersion ${config.schemaVersion} '
      'to $currentSchemaVersion.',
    );
  }
}
