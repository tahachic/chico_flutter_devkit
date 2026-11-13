import 'package:chico_flutter_devkit/chico_flutter_devkit.dart';
import 'package:chico_flutter_devkit/src/config/parser.dart';
import 'package:test/test.dart';

void main() {
  const parser = DevKitConfigParser();

  test('parses partial maps with defaults', () {
    final config = parser.parse({
      'schemaVersion': 1,
      'project': {'name': 'catalog', 'architecture': 'layered'},
      'flutter': {'state_management': 'cubit'},
    });

    expect(config.project.name, 'catalog');
    expect(config.project.architecture, Architecture.layered);
    expect(config.flutter.stateManagement, StateManagement.cubit);
    expect(config.flutter.routing, Routing.goRouter);
    expect(config.generation.overwrite, isFalse);
  });

  test('rejects unknown architecture', () {
    expect(
      () => parser.parse({
        'project': {'architecture': 'hexagonal'},
      }),
      throwsA(isA<ConfigException>()),
    );
  });
}
