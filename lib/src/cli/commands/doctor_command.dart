import 'dart:convert';

import '../../core/exit_codes.dart';
import '../../doctor/doctor_service.dart';
import '../../doctor/models.dart';
import '../../quality/tool_runner.dart';
import '../command.dart';

/// `devkit doctor` — diagnose the current Flutter project.
final class DoctorCommand extends DevKitCommand {
  DoctorCommand({
    required super.logger,
    required super.configService,
    required super.projectRootProvider,
    ToolRunner? toolRunner,
    DoctorService? doctorService,
  }) : _toolRunner = toolRunner,
       _doctorService = doctorService {
    argParser
      ..addFlag('json', help: 'Print machine-readable JSON.', negatable: false)
      ..addFlag(
        'fix',
        help: 'Apply safe automatic fixes (shows plan first).',
        negatable: false,
      )
      ..addFlag(
        'yes',
        abbr: 'y',
        help: 'Apply --fix without an extra confirmation prompt.',
        negatable: false,
      );
  }

  final ToolRunner? _toolRunner;
  final DoctorService? _doctorService;

  @override
  String get name => 'doctor';

  @override
  String get description => 'Diagnose the current Flutter project.';

  @override
  Future<int> run() async {
    final service =
        _doctorService ??
        DoctorService(
          configService: configService,
          toolRunner: _toolRunner ?? ProcessToolRunner(),
        );
    final root = projectRootProvider();
    final asJson = argResults!['json'] as bool;
    final fix = argResults!['fix'] as bool;

    final initial = await service.inspect(root);

    if (asJson && !fix) {
      logger.info(jsonEncode(initial.toJson()));
      return _exitFor(initial.overall);
    }

    if (!asJson) {
      _printReport(initial, title: 'CHICO PROJECT DOCTOR');
    }

    if (!fix) {
      return _exitFor(initial.overall);
    }

    final plan = await service.fix(root, dryRun: true);
    if (plan.planned.isEmpty) {
      logger.info('No safe automatic fixes available.');
      return _exitFor(initial.overall);
    }

    logger.info('Planned safe fixes:');
    for (final item in plan.planned) {
      logger.info('  - $item');
    }

    final apply =
        (argResults!['yes'] as bool) ||
        logger.raw.confirm('Apply these fixes?', defaultValue: false);
    if (!apply) {
      logger.info('No changes applied.');
      return _exitFor(initial.overall);
    }

    final result = await service.fix(root, dryRun: false);
    logger.success('Applied ${result.applied.length} fix(es).');
    final remainingPlanned = plan.planned
        .where((item) => !result.applied.contains(item))
        .toList(growable: false);
    if (remainingPlanned.isNotEmpty) {
      logger.warn('Fixes not applied:');
      for (final item in remainingPlanned) {
        logger.warn('  - $item');
      }
    }

    final finalReport = await service.inspect(root);
    if (!asJson) {
      logger.info('');
      _printReport(finalReport, title: 'DOCTOR (after fixes)');
      logger.info('Issues detected initially: ${initial.issues.length}');
      logger.info('Fixes applied: ${result.applied.length}');
      logger.info('Issues remaining: ${finalReport.issues.length}');
    } else {
      logger.info(
        jsonEncode({
          'initial': initial.toJson(),
          'fixesApplied': result.applied,
          'fixesFailed': remainingPlanned,
          'final': finalReport.toJson(),
        }),
      );
    }

    return _exitFor(finalReport.overall);
  }

  void _printReport(DoctorReport report, {required String title}) {
    logger.info(title);
    logger.info('');
    logger.info('Project: ${report.projectName}');
    logger.info('');
    for (final category in report.categories) {
      logger.info('${category.label}: ${category.status.name.toUpperCase()}');
    }
    if (report.issues.isNotEmpty) {
      logger.info('');
      logger.info('Issues:');
      for (final issue in report.issues) {
        final tag = switch (issue.severity) {
          DoctorSeverity.high => 'HIGH',
          DoctorSeverity.medium => 'MED',
          DoctorSeverity.low => 'LOW',
        };
        logger.info('[$tag] ${issue.message}');
        if (issue.details != null && verbose) {
          logger.detail('       ${issue.details}');
        }
      }
    } else {
      logger.success('No issues found.');
    }
  }

  int _exitFor(DoctorStatus status) {
    return switch (status) {
      DoctorStatus.fail => ExitCodes.failure,
      DoctorStatus.warning ||
      DoctorStatus.pass ||
      DoctorStatus.skip => ExitCodes.success,
    };
  }
}
