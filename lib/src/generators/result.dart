import '../fs/write_plan.dart';

/// Structured outcome of a generator run (never prints by itself).
final class GenerationResult {
  const GenerationResult({
    required this.generatorName,
    required this.writes,
    this.message,
  });

  final String generatorName;
  final WritePlanResult writes;
  final String? message;

  bool get isDryRun => writes.dryRun;

  List<String> get plannedPaths =>
      writes.results.map((result) => result.relativePath).toList();
}
