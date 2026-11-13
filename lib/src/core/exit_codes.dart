/// Process exit codes used consistently across all commands.
abstract final class ExitCodes {
  /// Successful completion.
  static const int success = 0;

  /// Invalid usage, bad arguments, or validation the user can fix.
  static const int usage = 64;

  /// Configuration error (invalid, missing, or unreadable config).
  static const int config = 65;

  /// Requested operation is not implemented yet.
  static const int notImplemented = 66;

  /// Unexpected execution / I/O / subprocess failure.
  static const int failure = 1;
}
