import '../injection/global_injector.dart';
import '../events/event_bus.dart';
import '../utils/module_logger.dart';
import 'plugin_contract.dart';

/// Utility class for sequential plugin initialization with detailed reporting.
///
/// Used internally by [MicrofrontendApp] — you generally don't need to use
/// this directly.
class PluginInitializer {
  final _logger = ModuleLogger('PluginInitializer');

  Future<PluginInitResult> initializeAll({
    required List<MicroPlugin> plugins,
    required GlobalInjector injector,
    required ModuleEventBus eventBus,
  }) async {
    final results = <PluginInitRecord>[];
    final sw = Stopwatch()..start();

    for (final plugin in plugins
      ..sort((a, b) => b.priority.compareTo(a.priority))) {
      final record = await _initOne(plugin, injector, eventBus);
      results.add(record);
    }

    sw.stop();
    _logger.info(
        'Plugin initialization complete: ${results.where((r) => r.success).length}/'
        '${results.length} succeeded in ${sw.elapsedMilliseconds}ms');

    return PluginInitResult(
      records: results,
      totalDuration: sw.elapsed,
    );
  }

  Future<PluginInitRecord> _initOne(
    MicroPlugin plugin,
    GlobalInjector injector,
    ModuleEventBus eventBus,
  ) async {
    final sw = Stopwatch()..start();
    try {
      await plugin.initialize(injector, eventBus).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw TimeoutException(
          'Plugin ${plugin.pluginId} initialization timed out after 10s',
        ),
      );
      sw.stop();
      return PluginInitRecord(
        pluginId: plugin.pluginId,
        pluginName: plugin.pluginName,
        success: true,
        durationMs: sw.elapsedMilliseconds,
      );
    } catch (e, st) {
      sw.stop();
      _logger.error(
          'Plugin ${plugin.pluginId} failed: $e', error: e, stackTrace: st);
      return PluginInitRecord(
        pluginId: plugin.pluginId,
        pluginName: plugin.pluginName,
        success: false,
        durationMs: sw.elapsedMilliseconds,
        error: e,
      );
    }
  }
}

class TimeoutException implements Exception {
  final String message;
  const TimeoutException(this.message);
  @override
  String toString() => 'TimeoutException: $message';
}

// ─── Result Types ─────────────────────────────────────────────────────────────

class PluginInitResult {
  final List<PluginInitRecord> records;
  final Duration totalDuration;

  int get successCount => records.where((r) => r.success).length;
  int get failureCount => records.where((r) => !r.success).length;
  bool get allSucceeded => failureCount == 0;

  const PluginInitResult({
    required this.records,
    required this.totalDuration,
  });
}

class PluginInitRecord {
  final String pluginId;
  final String pluginName;
  final bool success;
  final int durationMs;
  final Object? error;

  const PluginInitRecord({
    required this.pluginId,
    required this.pluginName,
    required this.success,
    required this.durationMs,
    this.error,
  });
}

// ─── No-op Implementations ───────────────────────────────────────────────────

/// A no-op analytics plugin. Useful for testing or when analytics is disabled.
class NoOpAnalyticsPlugin extends AnalyticsPlugin {
  @override
  String get pluginId => 'noop_analytics';
  @override
  String get pluginName => 'No-Op Analytics';

  @override
  Future<void> trackEvent(String eventName,
      {Map<String, dynamic>? parameters, String? moduleId}) async {}
  @override
  Future<void> trackScreen(String screenName,
      {String? moduleId, Map<String, dynamic>? extra}) async {}
  @override
  Future<void> setUserId(String userId) async {}
  @override
  Future<void> setUserProperty(String key, String value) async {}
  @override
  Future<void> resetUser() async {}
}

/// A no-op crash reporting plugin. Useful for development/testing.
class NoOpCrashReportingPlugin extends CrashReportingPlugin {
  @override
  String get pluginId => 'noop_crash';
  @override
  String get pluginName => 'No-Op Crash Reporting';

  @override
  Future<void> recordError(Object error, StackTrace stackTrace,
      {String? moduleId,
      Map<String, dynamic>? context,
      bool isFatal = false}) async {}
  @override
  Future<void> setUserContext(String userId,
      {Map<String, dynamic>? extra}) async {}
  @override
  Future<void> addBreadcrumb(String message,
      {Map<String, dynamic>? data}) async {}
  @override
  Future<void> clearBreadcrumbs() async {}
}
