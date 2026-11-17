import 'package:chico_flutter_devkit/chico_flutter_devkit.dart';
import 'package:test/test.dart';

void main() {
  group('DevKitConfigDefaults', () {
    test('creates schema version 1 defaults', () {
      final config = DevKitConfigDefaults.create(projectName: 'shop_app');

      expect(config.schemaVersion, currentSchemaVersion);
      expect(config.project.name, 'shop_app');
      expect(config.project.architecture, Architecture.clean);
      expect(config.flutter.stateManagement, StateManagement.bloc);
      expect(config.flutter.routing, Routing.goRouter);
      expect(config.chico.ui.enabled, isFalse);
      expect(config.chico.kit.enabled, isFalse);
      expect(config.chico.services.enabled, isFalse);
      expect(config.chico.ui.version, DefaultChicoVersions.ui);
      expect(config.chico.kit.version, DefaultChicoVersions.kit);
      expect(config.chico.services.version, DefaultChicoVersions.services);
      expect(config.generation.overwrite, isFalse);
      expect(config.generation.createBackups, isTrue);
    });
  });
}
