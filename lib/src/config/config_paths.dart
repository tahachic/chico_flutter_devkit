import 'dart:io';

import 'package:path/path.dart' as p;

/// Well-known configuration file locations.
abstract final class ConfigPaths {
  static const String projectDirName = '.chico';
  static const String configFileName = 'devkit.yaml';
  static const String schemaVersionKey = 'schemaVersion';

  /// Project-level config: `<root>/.chico/devkit.yaml`.
  static String projectConfigFile(String projectRoot) =>
      p.join(projectRoot, projectDirName, configFileName);

  /// Project-level directory: `<root>/.chico`.
  static String projectConfigDir(String projectRoot) =>
      p.join(projectRoot, projectDirName);

  /// User-level config directory.
  ///
  /// - Windows: `%USERPROFILE%\.chico`
  /// - macOS/Linux: `$HOME/.chico`
  static String userConfigDir({String? homeOverride}) {
    final home =
        homeOverride ??
        Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'];
    if (home == null || home.isEmpty) {
      throw StateError(
        'Unable to resolve user home directory for global DevKit config.',
      );
    }
    return p.join(home, projectDirName);
  }

  /// User-level config file.
  static String userConfigFile({String? homeOverride}) =>
      p.join(userConfigDir(homeOverride: homeOverride), configFileName);
}
