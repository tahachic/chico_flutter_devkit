import 'package:chico_flutter_devkit/chico_flutter_devkit.dart';
import 'package:chico_flutter_devkit/src/config/validator.dart';
import 'package:test/test.dart';

void main() {
  const validator = DevKitConfigValidator();

  test('accepts default configuration', () {
    expect(
      () => validator.validate(DevKitConfigDefaults.create()),
      returnsNormally,
    );
  });

  test('rejects invalid package name', () {
    final config = DevKitConfigDefaults.create().copyWith(
      project: DevKitConfigDefaults.create().project.copyWith(name: '123bad'),
    );

    expect(() => validator.validate(config), throwsA(isA<ConfigException>()));
  });

  test('rejects services without kit', () {
    final defaults = DevKitConfigDefaults.create();
    final config = defaults.copyWith(
      chico: defaults.chico.copyWith(
        kit: const ChicoPackageToggle(enabled: false),
        services: const ChicoPackageToggle(enabled: true),
      ),
    );

    expect(() => validator.validate(config), throwsA(isA<ConfigException>()));
  });

  test('rejects kit without ui', () {
    final defaults = DevKitConfigDefaults.create();
    final config = defaults.copyWith(
      chico: defaults.chico.copyWith(
        ui: const ChicoPackageToggle(enabled: false),
        kit: const ChicoPackageToggle(enabled: true),
      ),
    );

    expect(() => validator.validate(config), throwsA(isA<ConfigException>()));
  });

  test('rejects empty localization languages when enabled', () {
    final defaults = DevKitConfigDefaults.create();
    final config = defaults.copyWith(
      flutter: defaults.flutter.copyWith(
        localization: const LocalizationConfig(enabled: true, languages: []),
      ),
    );

    expect(() => validator.validate(config), throwsA(isA<ConfigException>()));
  });
}
