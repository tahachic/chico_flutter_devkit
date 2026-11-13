import 'dart:io';

import 'package:chico_flutter_devkit/chico_flutter_devkit.dart';

Future<void> main(List<String> arguments) async {
  final app = CliApp();
  final code = await app.run(arguments);
  exit(code);
}
