import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';
import 'package:yaml/yaml.dart';

import '../../core/exceptions.dart';
import '../../integrations/chico/chico_packages.dart';
import '../../pubspec/pubspec_editor.dart';
import '../context.dart';
import 'ui_imports.dart';

/// Ensures Chico packages required by generated UI are declared in pubspec.
///
/// Never silently mutates pubspec. Callers may pass `addMissingChico: true`
/// in [GenerationContext.extra] to explicitly install **missing** packages.
/// Existing dependency constraints are never overwritten.
abstract final class ChicoDependencyGuard {
  /// Packages required when generating Chico-backed UI for [context].
  static List<ChicoPackageId> requiredForUi(GenerationContext context) {
    if (!UiImports.useChico(context.config)) return const [];
    if (context.config.chico.kit.enabled) {
      return const [ChicoPackageId.ui, ChicoPackageId.kit];
    }
    if (context.config.chico.ui.enabled) {
      return const [ChicoPackageId.ui];
    }
    return const [];
  }

  /// Validates (and optionally installs missing) required Chico dependencies.
  static Future<void> ensure({
    required GenerationContext context,
    List<ChicoPackageId>? packages,
  }) async {
    final required = packages ?? requiredForUi(context);
    if (required.isEmpty) return;

    final pubspecPath = p.join(context.projectRoot, 'pubspec.yaml');
    final file = File(pubspecPath);
    if (!file.existsSync()) {
      throw ExecutionException(
        'Not a Dart/Flutter project.',
        details: 'Missing $pubspecPath',
      );
    }

    Map<String, String> declared;
    try {
      declared = await PubspecEditor.forProject(
        context.projectRoot,
      ).listDependencies();
    } catch (error) {
      throw ExecutionException(
        'Unable to read pubspec.yaml dependencies.',
        details: pubspecPath,
        cause: error,
      );
    }

    final missing = <ChicoPackageId>[];
    final incompatible = <String>[];

    for (final package in required) {
      final declaredConstraint = declared[package.packageName];
      if (declaredConstraint == null) {
        missing.add(package);
        continue;
      }

      final requiredConstraint = _constraintFor(context, package);
      final compatibility = evaluateCompatibility(
        packageName: package.packageName,
        declaredConstraint: declaredConstraint,
        requiredConstraint: requiredConstraint,
      );
      if (!compatibility.ok) {
        incompatible.add(compatibility.message);
      }
    }

    if (incompatible.isNotEmpty) {
      throw InvalidUsageException(
        'Incompatible Chico dependency constraint(s) in pubspec.yaml.',
        details:
            '${incompatible.map((m) => '  - $m').join('\n')}\n\n'
            'DevKit does not overwrite existing constraints. '
            'Update pubspec.yaml manually or align .chico/devkit.yaml versions.',
      );
    }

    if (missing.isEmpty) return;

    final addMissing = context.extra['addMissingChico'] == true;
    if (!addMissing || context.dryRun) {
      final lines = missing
          .map(
            (pkg) => '  - ${pkg.packageName}  →  devkit add ${pkg.packageName}',
          )
          .join('\n');
      throw InvalidUsageException(
        'Missing Chico ${missing.length == 1 ? 'dependency' : 'dependencies'} '
        'required by generated UI.',
        details:
            'Missing:\n$lines\n\n'
            'Add them first, or re-run with --add-missing-chico.\n'
            'Dry-run never modifies pubspec.yaml.',
      );
    }

    final editor = PubspecEditor.forProject(context.projectRoot);
    for (final package in missing) {
      // Only add packages that are absent — never rewrite existing entries.
      final current = await editor.listDependencies();
      if (current.containsKey(package.packageName)) continue;
      final constraint = _constraintFor(context, package);
      await editor.ensureDependency(
        packageName: package.packageName,
        constraint: constraint,
      );
    }
  }

  /// Returns whether [declaredConstraint] is compatible with [requiredConstraint].
  static ({bool ok, String message}) evaluateCompatibility({
    required String packageName,
    required String declaredConstraint,
    required String requiredConstraint,
  }) {
    final declaredRaw = declaredConstraint.trim();
    final requiredRaw = requiredConstraint.trim();

    if (declaredRaw.isEmpty ||
        declaredRaw == 'null' ||
        declaredRaw.startsWith('{')) {
      return (
        ok: false,
        message:
            '$packageName: malformed or non-hosted constraint '
            '"$declaredConstraint". Use a pub version constraint string '
            '(e.g. ^1.7.0).',
      );
    }

    late final VersionConstraint declared;
    late final VersionConstraint required;
    try {
      declared = VersionConstraint.parse(declaredRaw);
    } on FormatException catch (error) {
      return (
        ok: false,
        message:
            '$packageName: malformed declared constraint "$declaredRaw" '
            '(${error.message}).',
      );
    }
    try {
      required = VersionConstraint.parse(requiredRaw);
    } on FormatException catch (error) {
      return (
        ok: false,
        message:
            '$packageName: malformed required constraint "$requiredRaw" '
            '(${error.message}).',
      );
    }

    final intersection = declared.intersect(required);
    if (intersection.isEmpty) {
      return (
        ok: false,
        message:
            '$packageName: declared "$declaredRaw" does not satisfy required '
            '"$requiredRaw" (empty intersection).',
      );
    }

    return (ok: true, message: '');
  }

  static String _constraintFor(
    GenerationContext context,
    ChicoPackageId package,
  ) {
    final configured = switch (package) {
      ChicoPackageId.ui => context.config.chico.ui.version,
      ChicoPackageId.kit => context.config.chico.kit.version,
      ChicoPackageId.services => context.config.chico.services.version,
    };
    return configured ?? package.defaultConstraint;
  }

  /// Lightweight pubspec sanity check used by tests.
  static bool looksLikeValidPubspec(String contents) {
    try {
      final loaded = loadYaml(contents);
      return loaded is YamlMap && loaded['name'] != null;
    } catch (_) {
      return false;
    }
  }
}
