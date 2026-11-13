import 'version.dart';

/// ASCII banner shown on interactive root help.
String buildBanner({String version = packageVersion}) {
  return '''
╔══════════════════════════════════════════════════╗
║           CHICO FLUTTER DEVKIT                   ║
║   Professional Flutter Development Toolkit       ║
╚══════════════════════════════════════════════════╝

Version: $version
''';
}

/// Short one-line identity for non-banner contexts.
String buildIdentityLine({String version = packageVersion}) {
  return '$productName $version';
}
