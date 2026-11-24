/// Extracts and re-injects `// <devkit:custom id="...">` regions.
///
/// On regenerate, generated templates may include empty region stubs. User
/// content inside matching ids is preserved across `--sync` / overwrite.
abstract final class CustomRegions {
  static final RegExp _regionPattern = RegExp(
    r'// <devkit:custom id="([^"]+)">\r?\n([\s\S]*?)// </devkit:custom>',
    multiLine: true,
  );

  /// Returns region id → inner content (excluding markers).
  static Map<String, String> extract(String source) {
    final regions = <String, String>{};
    for (final match in _regionPattern.allMatches(source)) {
      final id = match.group(1)!;
      regions[id] = match.group(2) ?? '';
    }
    return regions;
  }

  /// Replaces empty/stub regions in [generated] with matching ids from [previous].
  ///
  /// If [previous] has no region for an id, the generated stub is kept.
  /// Malformed regions in [previous] are skipped (no corruption).
  static String merge({required String generated, required String? previous}) {
    if (previous == null || previous.isEmpty) return generated;
    final saved = extract(previous);
    if (saved.isEmpty) return generated;

    return generated.replaceAllMapped(_regionPattern, (match) {
      final id = match.group(1)!;
      final savedBody = saved[id];
      if (savedBody == null) return match.group(0)!;
      return '// <devkit:custom id="$id">\n$savedBody// </devkit:custom>';
    });
  }

  /// Empty region stub for generators.
  static String stub(String id, {String comment = 'User customizations'}) {
    return '// <devkit:custom id="$id">\n'
        '// $comment\n'
        '// </devkit:custom>';
  }

  /// True when [previous] matches [generated] aside from custom region bodies.
  static bool onlyCustomRegionsDiffer({
    required String previous,
    required String generated,
  }) {
    return _stripRegions(previous) == _stripRegions(generated);
  }

  static String _stripRegions(String source) {
    return source.replaceAll(_regionPattern, '');
  }
}
