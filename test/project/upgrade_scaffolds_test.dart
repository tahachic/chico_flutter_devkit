import 'dart:io';

import 'package:chico_flutter_devkit/src/generators/feature/feature_integration.dart';
import 'package:chico_flutter_devkit/src/project/upgrade_scaffolds_service.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tempRoot;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('devkit_upg_scaf_');
  });

  tearDown(() async {
    await tempRoot.delete(recursive: true);
  });

  test('upgrade scaffolds creates missing anchor stubs', () async {
    await Directory(p.join(tempRoot.path, '.chico')).create();
    final result = await UpgradeScaffoldsService().run(
      projectRoot: tempRoot.path,
    );
    expect(result.refreshed, isNotEmpty);
    expect(
      File(
        p.join(tempRoot.path, FeatureIntegration.featureRoutesPath),
      ).existsSync(),
      isTrue,
    );
    expect(
      File(
        p.join(tempRoot.path, FeatureIntegration.featureRegistrationsPath),
      ).readAsStringSync(),
      contains(FeatureIntegration.regsBegin),
    );
  });

  test('upgrade scaffolds dry-run does not write', () async {
    await Directory(p.join(tempRoot.path, '.chico')).create();
    final result = await UpgradeScaffoldsService().run(
      projectRoot: tempRoot.path,
      dryRun: true,
    );
    expect(result.dryRun, isTrue);
    expect(result.refreshed, isNotEmpty);
    expect(
      File(
        p.join(tempRoot.path, FeatureIntegration.featureRoutesPath),
      ).existsSync(),
      isFalse,
    );
  });
}
