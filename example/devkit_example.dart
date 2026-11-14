import 'dart:io';

import 'package:chico_flutter_devkit/chico_flutter_devkit.dart';

/// Minimal public-API example for pub.dev scoring and docs.
///
/// Prefer the `devkit` CLI for day-to-day work:
/// `dart pub global activate chico_flutter_devkit`
void main() {
  stdout.writeln('$productName $packageVersion');
  stdout.writeln('CLI executable: $executableName');

  final feature = NameConverter.parse('order_item');
  stdout.writeln(
    'NameConverter: ${feature.raw} → '
    '${feature.pascalCase} / ${feature.snakeCase} / ${feature.camelCase}',
  );

  final defaults = DevKitConfigDefaults.create(projectName: 'shop_app');
  stdout.writeln(
    'Default stack: ${defaults.project.architecture.yamlValue} + '
    '${defaults.flutter.stateManagement.yamlValue}',
  );
}
