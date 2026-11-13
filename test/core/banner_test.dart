import 'package:chico_flutter_devkit/src/core/banner.dart';
import 'package:chico_flutter_devkit/src/core/version.dart';
import 'package:test/test.dart';

void main() {
  test('banner includes product identity and version', () {
    final banner = buildBanner(version: '9.9.9');
    expect(banner, contains('CHICO FLUTTER DEVKIT'));
    expect(banner, contains('9.9.9'));
  });

  test('identity line includes product name', () {
    expect(buildIdentityLine(), contains(productName));
    expect(buildIdentityLine(), contains(packageVersion));
  });
}
