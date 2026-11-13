import '../../config/defaults.dart';

/// Known Chico ecosystem packages (verified on pub.dev).
enum ChicoPackageId {
  ui('chico_ui', DefaultChicoVersions.ui),
  kit('chico_kit', DefaultChicoVersions.kit),
  services('chico_services', DefaultChicoVersions.services);

  const ChicoPackageId(this.packageName, this.defaultConstraint);

  final String packageName;
  final String defaultConstraint;

  static ChicoPackageId parse(String raw) {
    final normalized = raw.trim().toLowerCase().replaceAll('-', '_');
    return ChicoPackageId.values.firstWhere(
      (value) =>
          value.packageName == normalized ||
          value.name == normalized ||
          'chico_$normalized' == value.packageName,
      orElse: () => throw FormatException(
        'Unknown Chico package "$raw". '
        'Expected: chico_ui, chico_kit, chico_services',
      ),
    );
  }
}
