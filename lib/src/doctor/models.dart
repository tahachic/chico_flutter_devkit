/// Severity of a doctor finding.
enum DoctorSeverity { high, medium, low }

/// Pass / warn / fail for a diagnostic category.
enum DoctorStatus { pass, warning, fail, skip }

/// One actionable doctor issue.
final class DoctorIssue {
  const DoctorIssue({
    required this.severity,
    required this.code,
    required this.message,
    this.fixId,
    this.details,
  });

  final DoctorSeverity severity;
  final String code;
  final String message;
  final String? details;

  /// Stable id used by `--fix` for safe automatic repairs.
  final String? fixId;

  bool get isFixable => fixId != null;

  Map<String, Object?> toJson() => {
    'severity': severity.name,
    'code': code,
    'message': message,
    if (details != null) 'details': details,
    if (fixId != null) 'fixId': fixId,
  };
}

/// Result for one diagnostic category.
final class DoctorCategoryResult {
  const DoctorCategoryResult({
    required this.id,
    required this.label,
    required this.status,
    this.issues = const [],
  });

  final String id;
  final String label;
  final DoctorStatus status;
  final List<DoctorIssue> issues;

  Map<String, Object?> toJson() => {
    'id': id,
    'label': label,
    'status': status.name,
    'issues': issues.map((issue) => issue.toJson()).toList(),
  };
}

/// Full doctor report.
final class DoctorReport {
  const DoctorReport({
    required this.projectName,
    required this.projectRoot,
    required this.categories,
  });

  final String projectName;
  final String projectRoot;
  final List<DoctorCategoryResult> categories;

  List<DoctorIssue> get issues =>
      categories.expand((category) => category.issues).toList(growable: false);

  List<DoctorIssue> get fixableIssues =>
      issues.where((issue) => issue.isFixable).toList(growable: false);

  DoctorStatus get overall {
    if (categories.any((c) => c.status == DoctorStatus.fail)) {
      return DoctorStatus.fail;
    }
    if (categories.any((c) => c.status == DoctorStatus.warning)) {
      return DoctorStatus.warning;
    }
    return DoctorStatus.pass;
  }

  Map<String, Object?> toJson() => {
    'projectName': projectName,
    'projectRoot': projectRoot,
    'overall': overall.name,
    'categories': categories.map((c) => c.toJson()).toList(),
    'issues': issues.map((i) => i.toJson()).toList(),
  };
}

/// Result of applying safe doctor fixes.
final class DoctorFixResult {
  const DoctorFixResult({
    required this.planned,
    required this.applied,
    required this.dryRun,
  });

  final List<String> planned;
  final List<String> applied;
  final bool dryRun;
}
