/// How a planned write should treat an existing destination.
enum FileWriteMode {
  /// Create only when the file does not exist.
  create,

  /// Overwrite an existing file (optionally after backup).
  overwrite,

  /// Skip if the destination already exists.
  skipIfExists,
}

/// One planned filesystem write.
final class PlannedFileWrite {
  const PlannedFileWrite({
    required this.relativePath,
    required this.content,
    this.mode = FileWriteMode.create,
  });

  /// Path relative to the authorized project root.
  final String relativePath;

  /// UTF-8 text content to write.
  final String content;

  final FileWriteMode mode;
}

/// Outcome for a single planned write.
enum FileWriteOutcome {
  created,
  overwritten,
  backedUpAndOverwritten,
  skippedExists,
  dryRun,
}

/// Result entry for one applied write.
final class FileWriteResult {
  const FileWriteResult({
    required this.relativePath,
    required this.absolutePath,
    required this.outcome,
    this.backupPath,
  });

  final String relativePath;
  final String absolutePath;
  final FileWriteOutcome outcome;
  final String? backupPath;
}

/// Aggregate result of applying a write plan.
final class WritePlanResult {
  const WritePlanResult({required this.results, required this.dryRun});

  final List<FileWriteResult> results;
  final bool dryRun;

  int get createdCount =>
      results.where((r) => r.outcome == FileWriteOutcome.created).length;

  int get overwrittenCount => results
      .where(
        (r) =>
            r.outcome == FileWriteOutcome.overwritten ||
            r.outcome == FileWriteOutcome.backedUpAndOverwritten,
      )
      .length;

  int get skippedCount =>
      results.where((r) => r.outcome == FileWriteOutcome.skippedExists).length;
}
