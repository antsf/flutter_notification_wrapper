// ignore_for_file: avoid_positional_boolean_parameters, use_setters_to_change_properties, lines_longer_than_80_chars

import 'package:flutter/foundation.dart';
// import 'package:meta/meta.dart';

/// Log levels for controlling logging output
enum LogLevel {
  /// Verbose debug information
  debug,

  /// General information
  info,

  /// Warning messages
  warning,

  /// Error messages
  error,

  /// No logging
  none,
}

/// A simple, configurable logger for the notification wrapper package.
///
/// This logger provides different log levels and can be configured to
/// show or hide logs based on the current log level setting.
///
/// Example usage:
/// ```dart
/// final logger = Logger('MyClass');
/// logger.d('Debug message');
/// logger.i('Info message');
/// logger.w('Warning message');
/// logger.e('Error message');
/// ```
@immutable
class Logger {
  /// Creates a new logger with the specified name/tag.
  const Logger(this.name);

  /// Creates a logger with a formatted class name.
  ///
  /// This is useful for creating loggers from class types:
  /// ```dart
  /// final logger = Logger.forClass(MyClass);
  /// ```
  factory Logger.forClass(Type type) => Logger(type.toString());

  /// Creates a logger for a specific feature or module.
  ///
  /// This is useful for grouping related functionality:
  /// ```dart
  /// final logger = Logger.forFeature('Notifications');
  /// ```
  factory Logger.forFeature(String feature) => Logger('Feature:$feature');

  /// The name/tag for this logger instance
  final String name;

  /// Global log level - only messages at this level or higher will be shown
  static LogLevel _globalLogLevel = kDebugMode ? LogLevel.debug : LogLevel.info;

  /// Whether to include timestamps in log messages
  static bool _includeTimestamp = true;

  /// Whether to include the logger name in log messages
  static bool _includeLoggerName = true;

  /// Sets the global log level for all logger instances.
  static void setLogLevel(LogLevel level) {
    _globalLogLevel = level;
  }

  /// Gets the current global log level.
  static LogLevel get logLevel => _globalLogLevel;

  /// Configures timestamp inclusion in log messages.
  static void setIncludeTimestamp(bool include) {
    _includeTimestamp = include;
  }

  /// Configures logger name inclusion in log messages.
  static void setIncludeLoggerName(bool include) {
    _includeLoggerName = include;
  }

  /// Logs a debug message.
  void d(String message, [Object? error, StackTrace? stackTrace]) {
    _log(LogLevel.debug, message, error, stackTrace);
  }

  /// Logs an info message.
  void i(String message, [Object? error, StackTrace? stackTrace]) {
    _log(LogLevel.info, message, error, stackTrace);
  }

  /// Logs a warning message.
  void w(String message, [Object? error, StackTrace? stackTrace]) {
    _log(LogLevel.warning, message, error, stackTrace);
  }

  /// Logs an error message.
  void e(String message, [Object? error, StackTrace? stackTrace]) {
    _log(LogLevel.error, message, error, stackTrace);
  }

  /// Internal logging method that handles the actual logging logic.
  void _log(
    LogLevel level,
    String message, [
    Object? error,
    StackTrace? stackTrace,
  ]) {
    // Check if this log level should be shown
    if (!_shouldLog(level)) return;

    final buffer = StringBuffer();

    // Add timestamp if enabled
    if (_includeTimestamp) {
      buffer.write('[${DateTime.now().toIso8601String()}] ');
    }

    // Add logger name if enabled
    if (_includeLoggerName) {
      buffer.write('[$name] ');
    }

    buffer
      // Add log level prefix
      ..write('[${_getLevelPrefix(level)}] ')
      // Add the main message
      ..write(message);

    // Add error information if provided
    if (error != null) {
      buffer.write('\nError: $error');
    }

    // Add stack trace if provided
    if (stackTrace != null) {
      buffer.write('\nStack trace:\n$stackTrace');
    }

    // Output the log message
    debugPrint(buffer.toString());
  }

  /// Determines if a message at the given level should be logged.
  bool _shouldLog(LogLevel level) => level.index >= _globalLogLevel.index;

  /// Gets the string prefix for a log level.
  String _getLevelPrefix(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return 'DEBUG';
      case LogLevel.info:
        return 'INFO';
      case LogLevel.warning:
        return 'WARN';
      case LogLevel.error:
        return 'ERROR';
      case LogLevel.none:
        return 'NONE';
    }
  }

  @override
  String toString() => 'Logger($name)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Logger && runtimeType == other.runtimeType && name == other.name;

  @override
  int get hashCode => name.hashCode;
}
