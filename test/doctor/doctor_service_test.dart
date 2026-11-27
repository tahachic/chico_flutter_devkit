import 'dart:io';

import 'package:chico_flutter_devkit/chico_flutter_devkit.dart';
import 'package:chico_flutter_devkit/src/doctor/doctor_service.dart';
import 'package:chico_flutter_devkit/src/doctor/models.dart';
import 'package:chico_flutter_devkit/src/project/flutter_cli.dart';
import 'package:chico_flutter_devkit/src/project/generate_manifest.dart';
import 'package:chico_flutter_devkit/src/quality/tool_runner.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tempRoot;
  late Directory homeDir;
  late ConfigService configService;
  late FakeToolRunner toolRunner;
  late FakeFlutterCli flutterCli;
  late DoctorService doctor;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('devkit_doctor_');
    homeDir = await Directory.systemTemp.createTemp('devkit_doctor_home_');
    configService = ConfigService(homeOverride: homeDir.path);
    toolRunner = FakeToolRunner();
    flutterCli = FakeFlutterCli();
    doctor = DoctorService(
      configService: configService,
      toolRunner: toolRunner,
      flutterCli: flutterCli,
    );
  });

  tearDown(() async {
    await tempRoot.delete(recursive: true);
    await homeDir.delete(recursive: true);
  });

  Future<void> writePubspec() async {
    await File(p.join(tempRoot.path, 'pubspec.yaml')).writeAsString('''
name: shop_app
description: test
version: 1.0.0
environment:
  sdk: ^3.8.0
dependencies:
  flutter:
    sdk: flutter
''');
  }

  test('inspect reports missing config and analysis options', () async {
    await writePubspec();
    await Directory(p.join(tempRoot.path, 'lib')).create();
    await File(
      p.join(tempRoot.path, 'lib', 'main.dart'),
    ).writeAsString('void main() {}');

    final report = await doctor.inspect(tempRoot.path);
    expect(report.projectName, 'shop_app');
    expect(report.overall, DoctorStatus.warning);
    expect(
      report.issues.map((i) => i.code),
      containsAll([
        'config.missing',
        'quality.analysis_options_missing',
        'tests.dir_missing',
      ]),
    );
  });

  test('fix applies safe repairs without network pub get', () async {
    await writePubspec();
    await configService.initProjectConfig(
      projectRoot: tempRoot.path,
      config: DevKitConfigDefaults.create(projectName: 'shop_app'),
    );

    final plan = await doctor.fix(tempRoot.path, dryRun: true);
    expect(plan.planned, isNotEmpty);
    expect(plan.planned.any((item) => item.contains('run_pub_get')), isFalse);

    final result = await doctor.fix(tempRoot.path, dryRun: false);
    expect(result.applied, isNotEmpty);
    expect(Directory(p.join(tempRoot.path, 'lib')).existsSync(), isTrue);
    expect(Directory(p.join(tempRoot.path, 'test')).existsSync(), isTrue);
    expect(
      File(p.join(tempRoot.path, 'analysis_options.yaml')).existsSync(),
      isTrue,
    );
    expect(
      File(p.join(tempRoot.path, 'pubspec.yaml')).readAsStringSync(),
      isNot(contains('chico_ui')),
      reason: 'Material-first defaults do not add Chico via doctor fix',
    );
    expect(toolRunner.calls, isEmpty);
  });

  test('environment fail when flutter is missing', () async {
    await writePubspec();
    final failing = DoctorService(
      configService: configService,
      toolRunner: FakeToolRunner(flutterAvailable: false),
      flutterCli: flutterCli,
    );
    final report = await failing.inspect(tempRoot.path);
    expect(report.overall, DoctorStatus.fail);
    expect(report.issues.any((i) => i.code == 'env.flutter_missing'), isTrue);
  });

  test('warns when Flutter ≥ 3.47 and material_ui is missing', () async {
    await writePubspec();
    await Directory(p.join(tempRoot.path, 'lib')).create();
    await File(
      p.join(tempRoot.path, 'lib', 'main.dart'),
    ).writeAsString('void main() {}');
    doctor = DoctorService(
      configService: configService,
      toolRunner: toolRunner,
      flutterCli: FakeFlutterCli(materialUiSupported: true),
    );

    final report = await doctor.inspect(tempRoot.path);
    expect(
      report.issues.any((i) => i.code == 'deps.material_ui_missing'),
      isTrue,
    );
    expect(
      report.issues
          .firstWhere((i) => i.code == 'deps.material_ui_missing')
          .details,
      contains('flutter pub add material_ui'),
    );
  });

  test('no material_ui warn when dependency already present', () async {
    await File(p.join(tempRoot.path, 'pubspec.yaml')).writeAsString('''
name: shop_app
description: test
version: 1.0.0
environment:
  sdk: ^3.8.0
dependencies:
  flutter:
    sdk: flutter
  material_ui: ^1.0.0
''');
    await Directory(p.join(tempRoot.path, 'lib')).create();
    doctor = DoctorService(
      configService: configService,
      toolRunner: toolRunner,
      flutterCli: FakeFlutterCli(materialUiSupported: true),
    );

    final report = await doctor.inspect(tempRoot.path);
    expect(
      report.issues.any((i) => i.code == 'deps.material_ui_missing'),
      isFalse,
    );
  });

  test('inspect warns on generate manifest drift', () async {
    await writePubspec();
    await Directory(p.join(tempRoot.path, 'lib')).create();
    await File(
      p.join(tempRoot.path, 'lib', 'main.dart'),
    ).writeAsString('void main() {}');
    await configService.initProjectConfig(
      projectRoot: tempRoot.path,
      config: DevKitConfigDefaults.create(projectName: 'shop_app'),
    );

    final tracked = File(p.join(tempRoot.path, 'lib', 'tracked.dart'));
    await tracked.writeAsString('// generated\n');
    final manifest = GenerateManifest.load(tempRoot.path);
    manifest.upsert(
      relativePath: 'lib/tracked.dart',
      generator: 'model',
      content: '// generated\n',
    );
    await manifest.save();

    await tracked.writeAsString('// generated\n// user changed\n');

    final report = await doctor.inspect(tempRoot.path);
    expect(
      report.issues.any((i) => i.code == 'generate.manifest_drift'),
      isTrue,
    );
    expect(
      report.issues
          .firstWhere((i) => i.code == 'generate.manifest_drift')
          .details,
      contains('lib/tracked.dart'),
    );
    expect(
      report.issues
          .firstWhere((i) => i.code == 'generate.manifest_drift')
          .details,
      contains('upgrade scaffolds'),
    );
  });
}
