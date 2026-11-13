import 'exit_codes.dart';

/// Base exception for all DevKit failures that map to exit codes.
sealed class DevKitException implements Exception {
  const DevKitException(this.message, {this.details, this.cause});

  final String message;
  final String? details;
  final Object? cause;

  int get exitCode;

  @override
  String toString() {
    final buffer = StringBuffer(message);
    if (details != null && details!.isNotEmpty) {
      buffer.write('\n$details');
    }
    return buffer.toString();
  }
}

/// User-facing usage / argument error.
final class InvalidUsageException extends DevKitException {
  const InvalidUsageException(super.message, {super.details, super.cause});

  @override
  int get exitCode => ExitCodes.usage;
}

/// Invalid or unreadable configuration.
final class ConfigException extends DevKitException {
  const ConfigException(super.message, {super.details, super.cause});

  @override
  int get exitCode => ExitCodes.config;
}

/// Feature not available in the current phase / build.
final class NotImplementedException extends DevKitException {
  const NotImplementedException(super.message, {super.details, super.cause});

  @override
  int get exitCode => ExitCodes.notImplemented;
}

/// Unexpected runtime failure.
final class ExecutionException extends DevKitException {
  const ExecutionException(super.message, {super.details, super.cause});

  @override
  int get exitCode => ExitCodes.failure;
}

/// Template parsing / rendering failure.
final class TemplateException extends DevKitException {
  const TemplateException(super.message, {super.details, super.cause});

  @override
  int get exitCode => ExitCodes.failure;
}
