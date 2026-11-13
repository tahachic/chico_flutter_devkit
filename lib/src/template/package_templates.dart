import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;

/// Locates the shipped `templates/` directory for this package.
abstract final class PackageTemplates {
  /// Resolves the absolute path to the package `templates/` folder.
  ///
  /// Works for `dart run`, local path deps, and global activation when the
  /// package layout is preserved.
  static Future<String?> resolveRoot() async {
    try {
      final packageUri = await Isolate.resolvePackageUri(
        Uri.parse('package:chico_flutter_devkit/chico_flutter_devkit.dart'),
      );
      if (packageUri == null || !packageUri.isScheme('file')) {
        return _fallbackFromScript();
      }
      final libFile = File.fromUri(packageUri);
      final packageRoot = libFile.parent.parent.path;
      final templates = Directory(p.join(packageRoot, 'templates'));
      if (templates.existsSync()) {
        return templates.path;
      }
    } catch (_) {
      // Fall through to script-based lookup.
    }
    return _fallbackFromScript();
  }

  static String? _fallbackFromScript() {
    final script = Platform.script;
    if (!script.isScheme('file')) return null;
    var dir = File.fromUri(script).parent;
    for (var i = 0; i < 6; i++) {
      final candidate = Directory(p.join(dir.path, 'templates'));
      if (candidate.existsSync()) {
        return candidate.path;
      }
      final parent = dir.parent;
      if (parent.path == dir.path) break;
      dir = parent;
    }
    return null;
  }
}
