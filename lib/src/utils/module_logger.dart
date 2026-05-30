import 'package:logging/logging.dart';
import 'package:flutter/foundation.dart';

/// Structured logger for the micro-frontend system.
///
/// Each component gets its own named logger. All logs are tagged with
/// the component name for easy filtering.
///
/// ```dart
/// final _logger = ModuleLogger('AuthModule');
/// _logger.info('User signed in');
/// _logger.error('Auth failed', error: exception, stackTrace: st);
/// _logger.debug('Token refreshed');   // only in debug mode
/// ```
class ModuleLogger {
  final Logger _logger;
  static bool debugMode = false;
  static final List<LogRecord> _history = [];
  static const int _maxHistory = 500;

  ModuleLogger(String name) : _logger = Logger(name);

  // ─── Logging Methods ───────────────────────────────────────────────────────

  void debug(String message) {
    if (debugMode || kDebugMode) {
      _log(Level.FINE, message);
    }
  }

  void info(String message) => _log(Level.INFO, message);

  void warning(String message, {Object? error, StackTrace? stackTrace}) {
    _log(Level.WARNING, message, error: error, stackTrace: stackTrace);
  }

  void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    _log(Level.SEVERE, message, error: error, stackTrace: stackTrace);
  }

  void critical(String message, {Object? error, StackTrace? stackTrace}) {
    _log(Level.SHOUT, message, error: error, stackTrace: stackTrace);
  }

  // ─── Internal ──────────────────────────────────────────────────────────────

  void _log(
    Level level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    final record = LogRecord(
      level,
      message,
      _logger.name,
      error,
      stackTrace,
    );

    // Store in history
    _history.add(record);
    if (_history.length > _maxHistory) _history.removeAt(0);

    // Output to console
    if (kDebugMode || level >= Level.INFO) {
      _printRecord(record);
    }
  }

  void _printRecord(LogRecord record) {
    final emoji = _emoji(record.level);
    final time = _formatTime(record.time);
    final tag = '[${record.loggerName}]';

    // ignore: avoid_print
    print('$emoji $time $tag ${record.message}');
    if (record.error != null) {
      // ignore: avoid_print
      print('   ⚠ Error: ${record.error}');
    }
    if (record.stackTrace != null && debugMode) {
      // ignore: avoid_print
      print('   📍 ${record.stackTrace.toString().split('\n').take(5).join('\n   ')}');
    }
  }

  static String _emoji(Level level) {
    if (level >= Level.SHOUT) return '💥';
    if (level >= Level.SEVERE) return '❌';
    if (level >= Level.WARNING) return '⚠️ ';
    if (level >= Level.INFO) return 'ℹ️ ';
    return '🔍';
  }

  static String _formatTime(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}:'
      '${t.second.toString().padLeft(2, '0')}.'
      '${t.millisecond.toString().padLeft(3, '0')}';

  // ─── Global Log History ────────────────────────────────────────────────────

  /// Returns the most recent log records.
  static List<LogRecord> recentLogs({int count = 50}) =>
      _history.reversed.take(count).toList();

  /// Clears all stored log history.
  static void clearHistory() => _history.clear();
}
