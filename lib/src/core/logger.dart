import 'package:mason_logger/mason_logger.dart';
import 'package:meta/meta.dart';

/// Thin wrapper around [Logger] with DevKit defaults.
final class DevKitLogger {
  DevKitLogger({Level level = Level.info, Logger? logger})
    : _logger = logger ?? Logger(level: level);

  final Logger _logger;

  Logger get raw => _logger;

  void setLevel(Level level) => _logger.level = level;

  void info(String message) => _logger.info(message);

  void detail(String message) => _logger.detail(message);

  void success(String message) => _logger.success(message);

  void warn(String message) => _logger.warn(message);

  void err(String message) => _logger.err(message);

  Progress progress(String message) => _logger.progress(message);

  @visibleForTesting
  Logger get testLogger => _logger;
}
