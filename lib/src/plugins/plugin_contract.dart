import '../contracts/module_contract.dart';
import '../injection/global_injector.dart';
import '../events/event_bus.dart';

/// Base contract for all plugins in the micro-frontend system.
///
/// Plugins are **cross-cutting concerns** — they apply to the entire system
/// without being tied to a specific feature module.
///
/// Typical plugins:
/// - 📊 Analytics & event tracking
/// - 🔥 Crash reporting & error monitoring
/// - 🚦 Feature flags & remote configuration
/// - 🔍 Performance monitoring & APM
/// - 🔐 Security & certificate pinning
/// - 🧪 A/B testing
/// - 📝 Centralized logging
///
/// ## Difference between Module and Plugin
/// | Aspect | Module | Plugin |
/// |--------|--------|--------|
/// | Has screens/routes | ✅ | ❌ |
/// | Has business logic | ✅ | ❌ |
/// | Cross-cutting | ❌ | ✅ |
/// | Lifecycle callbacks | Per-module | Per-module + system |
///
/// ## Example: Analytics Plugin
/// ```dart
/// class FirebaseAnalyticsPlugin extends AnalyticsPlugin {
///   @override String get pluginId => 'firebase_analytics';
///
///   @override
///   Future<void> initialize(GlobalInjector injector, ModuleEventBus bus) async {
///     await Firebase.initializeApp();
///     // Expose analytics globally
///     injector.registerSingleton<AnalyticsService>(FirebaseAnalytics.instance);
///   }
///
///   @override
///   Future<void> trackScreen(String name, {String? moduleId}) async {
///     await FirebaseAnalytics.instance.setCurrentScreen(screenName: name);
///   }
/// }
/// ```
abstract class MicroPlugin {
  /// Unique ID for this plugin.
  String get pluginId;

  /// Human-readable name.
  String get pluginName;

  /// Semantic version.
  String get version => '1.0.0';

  /// Initialization priority. Higher value = initialized first.
  int get priority => 0;

  /// Whether this plugin must be initialized BEFORE any modules.
  bool get initializeBeforeModules => false;

  // ─── Lifecycle ─────────────────────────────────────────────────────────────

  /// Initialize the plugin. Called once at startup.
  Future<void> initialize(
    GlobalInjector injector,
    ModuleEventBus eventBus,
  ) async {}

  /// Called after all modules have been registered and are ready.
  Future<void> onAllModulesReady(List<String> moduleIds) async {}

  // ─── Module Lifecycle Hooks ────────────────────────────────────────────────

  /// Called each time a module is registered with the system.
  Future<void> onModuleRegistered(MicroModule module) async {}

  /// Called each time a module becomes ready.
  Future<void> onModuleReady(MicroModule module) async {}

  /// Called each time a module is disposed.
  Future<void> onModuleDisposed(String moduleId) async {}

  // ─── Error Handling ────────────────────────────────────────────────────────

  /// Called when an unhandled error occurs in any module.
  Future<void> onError(
    Object error,
    StackTrace stackTrace, {
    String? moduleId,
    bool isFatal = false,
  }) async {}

  // ─── Cleanup ───────────────────────────────────────────────────────────────

  Future<void> dispose() async {}

  @override
  String toString() => 'MicroPlugin($pluginId v$version)';
}

// ─── Specialized Plugin Contracts ─────────────────────────────────────────────

/// Contract for analytics plugins (Firebase Analytics, Mixpanel, etc.).
abstract class AnalyticsPlugin extends MicroPlugin {
  Future<void> trackEvent(
    String eventName, {
    Map<String, dynamic>? parameters,
    String? moduleId,
  });

  Future<void> trackScreen(
    String screenName, {
    String? moduleId,
    Map<String, dynamic>? extra,
  });

  Future<void> setUserId(String userId);
  Future<void> setUserProperty(String key, String value);
  Future<void> resetUser();
}

/// Contract for crash reporting plugins (Sentry, Firebase Crashlytics, etc.).
abstract class CrashReportingPlugin extends MicroPlugin {
  Future<void> recordError(
    Object error,
    StackTrace stackTrace, {
    String? moduleId,
    Map<String, dynamic>? context,
    bool isFatal = false,
  });

  Future<void> setUserContext(String userId, {Map<String, dynamic>? extra});
  Future<void> addBreadcrumb(String message, {Map<String, dynamic>? data});
  Future<void> clearBreadcrumbs();
}

/// Contract for feature flag plugins (LaunchDarkly, Firebase RemoteConfig, etc.).
abstract class FeatureFlagsPlugin extends MicroPlugin {
  bool isEnabled(String flagName, {bool defaultValue = false});
  String getString(String key, {String defaultValue = ''});
  int getInt(String key, {int defaultValue = 0});
  double getDouble(String key, {double defaultValue = 0.0});
  Map<String, dynamic> getJson(String key, {Map<String, dynamic>? defaultValue});

  Future<void> fetchAndActivate();
  Stream<String> get flagChanges; // Emits flagName on each change
}

/// Contract for performance monitoring plugins.
abstract class PerformancePlugin extends MicroPlugin {
  Future<void> startTrace(String traceName, {String? moduleId});
  Future<void> stopTrace(String traceName);
  Future<void> setTraceAttribute(
    String traceName,
    String key,
    String value,
  );
  Future<void> recordNetworkRequest({
    required String url,
    required String method,
    required int statusCode,
    required int responseTimeMs,
    required int requestSize,
    required int responseSize,
  });
}
