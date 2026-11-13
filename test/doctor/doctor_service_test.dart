import 'dart:io';

import 'package:chico_flutter_devkit/chico_flutter_devkit.dart';
import 'package:chico_flutter_devkit/src/doctor/doctor_service.dart';
import 'package:chico_flutter_devkit/src/doctor/models.dart';
import 'package:chico_flutter_devkit/src/quality/tool_runner.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tempRoot;
  late Directory homeDir;
  late ConfigService configService;
  late FakeToolRunner toolRunner;
  late DoctorService doctor;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('devkit_doctor_');
    homeDir = await Directory.systemTemp.createTemp('devkit_doctor_home_');
    configService = ConfigService(homeOverride: homeDir.path);
    toolRunner = FakeToolRunner();
    doctor = DoctorService(
      configService: configService,
      toolRunner: toolRunner,
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
      contains('chico_ui'),
    );
    expect(toolRunner.calls, isEmpty);
  });

  test('environment fail when flutter is missing', () async {
    await writePubspec();
    final failing = DoctorService(
      configService: configService,
      toolRunner: FakeToolRunner(flutterAvailable: false),
    );
    final report = await failing.inspect(tempRoot.path);
    expect(report.overall, DoctorStatus.fail);
    expect(report.issues.any((i) => i.code == 'env.flutter_missing'), isTrue);
  });
}
