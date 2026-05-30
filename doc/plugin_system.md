# Plugin System

The plugin system provides a structured way to add **cross-cutting concerns** to
your micro-frontend application — analytics, crash reporting, feature flags,
performance monitoring, and more — without coupling any module to a specific SDK.

---

## Core Concept

| | Module | Plugin |
|---|---|---|
| Has screens / routes | ✅ | ❌ |
| Has business logic | ✅ | ❌ |
| Cross-cutting concern | ❌ | ✅ |
| Scoped to one feature | ✅ | ❌ |
| App-wide lifecycle hooks | ❌ | ✅ |

---

## `MicroPlugin` — base contract

Every plugin extends `MicroPlugin`:

```dart
abstract class MicroPlugin {
  String get pluginId;        // unique, stable identifier
  String get pluginName;      // human-readable label
  String get version => '1.0.0';
  int    get priority => 0;   // higher = initialized first
  bool   get initializeBeforeModules => false;

  Future<void> initialize(GlobalInjector injector, ModuleEventBus eventBus);
  Future<void> onAllModulesReady(List<String> moduleIds) async {}
  Future<void> onModuleRegistered(MicroModule module) async {}
  Future<void> onModuleReady(MicroModule module) async {}
  Future<void> onModuleDisposed(String moduleId) async {}
  Future<void> onError(Object error, StackTrace st, {String? moduleId, bool isFatal}) async {}
  Future<void> dispose() async {}
}
```

---

## Specialized contracts

### `AnalyticsPlugin`

```dart
class FirebaseAnalyticsPlugin extends AnalyticsPlugin {
  @override String get pluginId => 'firebase_analytics';
  @override String get pluginName => 'Firebase Analytics';

  @override
  Future<void> initialize(GlobalInjector injector, ModuleEventBus bus) async {
    await Firebase.initializeApp();
  }

  @override
  Future<void> trackEvent(String name,
      {Map<String, dynamic>? parameters, String? moduleId}) async {
    await FirebaseAnalytics.instance.logEvent(name: name, parameters: parameters);
  }

  @override
  Future<void> trackScreen(String name,
      {String? moduleId, Map<String, dynamic>? extra}) async {
    await FirebaseAnalytics.instance.setCurrentScreen(screenName: name);
  }

  @override Future<void> setUserId(String userId) async { ... }
  @override Future<void> setUserProperty(String key, String value) async { ... }
  @override Future<void> resetUser() async { ... }
}
```

### `CrashReportingPlugin`

```dart
class SentryCrashPlugin extends CrashReportingPlugin {
  @override String get pluginId => 'sentry';
  @override String get pluginName => 'Sentry';

  @override
  Future<void> initialize(GlobalInjector injector, ModuleEventBus bus) async {
    await SentryFlutter.init((options) => options.dsn = '...');
  }

  @override
  Future<void> recordError(Object error, StackTrace st,
      {String? moduleId, Map<String, dynamic>? context, bool isFatal = false}) async {
    await Sentry.captureException(error, stackTrace: st);
  }

  @override Future<void> setUserContext(String userId, {Map<String, dynamic>? extra}) async { ... }
  @override Future<void> addBreadcrumb(String message, {Map<String, dynamic>? data}) async { ... }
  @override Future<void> clearBreadcrumbs() async { ... }
}
```

### `FeatureFlagsPlugin`

```dart
class RemoteConfigPlugin extends FeatureFlagsPlugin {
  @override String get pluginId => 'remote_config';
  @override String get pluginName => 'Remote Config';

  @override
  bool isEnabled(String flagName, {bool defaultValue = false}) =>
      FirebaseRemoteConfig.instance.getBool(flagName);

  @override Future<void> fetchAndActivate() async {
    await FirebaseRemoteConfig.instance.fetchAndActivate();
  }

  @override Stream<String> get flagChanges => ... ;
  // ... getString / getInt / getDouble / getJson
}
```

---

## `PluginRegistry` — managing plugins at runtime

`PluginRegistry` is the runtime container. `MicrofrontendApp` creates it
internally; you normally interact with it via `MicrofrontendApp`.

```dart
final registry = PluginRegistry(
  globalInjector: globalInjector,
  eventBus: eventBus,
);

// Phase 1 — before modules load
await registry.initializeAll(plugins, beforeModules: true);

// Phase 2 — after modules are ready
await registry.initializeAll(plugins, beforeModules: false);
```

### Retrieving plugins

```dart
// By ID and type
final analytics = registry.getPlugin<AnalyticsPlugin>('firebase_analytics');

// By type only (first match)
final flags = registry.getPluginOfType<FeatureFlagsPlugin>();
```

### Lifecycle notifications

```dart
// Called by ModuleRegistry after all modules are ready
await registry.notifyModulesReady(registry.registeredModuleIds);

// Called by ModuleRegistry when any module throws
await registry.notifyError(error, stackTrace, moduleId: 'shop');
```

---

## `PluginInitializer` — lower-level sequential init

Use `PluginInitializer` when you need detailed per-plugin timing and error
capture without the full `PluginRegistry` setup:

```dart
final initializer = PluginInitializer();

final result = await initializer.initializeAll(
  plugins: [analyticsPlugin, crashPlugin],
  injector: globalInjector,
  eventBus: eventBus,
);

print('${result.successCount}/${result.records.length} succeeded');
print('Total time: ${result.totalDuration.inMilliseconds}ms');

for (final record in result.records) {
  if (!record.success) {
    print('${record.pluginName} failed: ${record.error}');
  }
}
```

---

## No-op implementations

Two built-in no-op implementations are provided for testing and
environments where a real SDK is not available:

```dart
// In tests or CI
final analytics = NoOpAnalyticsPlugin();
final crash     = NoOpCrashReportingPlugin();
```

---

## Initialization phases

Plugins are split across **two phases**:

| Phase | `initializeBeforeModules` | Typical use |
|-------|--------------------------|-------------|
| Pre-module | `true` | Crash reporting (must catch errors during module init) |
| Post-module | `false` (default) | Analytics, feature flags (need DI services registered by modules) |

```dart
MicrofrontendApp(
  modules: [...],
  plugins: [
    SentryCrashPlugin(),           // initializeBeforeModules: override to true
    FirebaseAnalyticsPlugin(),     // default false — runs after modules
    RemoteConfigPlugin(),
  ],
)
```

---

## Writing a minimal custom plugin

```dart
class MyAuditPlugin extends MicroPlugin {
  final _log = <String>[];

  @override String get pluginId => 'audit';
  @override String get pluginName => 'Audit Log';

  @override
  Future<void> initialize(GlobalInjector injector, ModuleEventBus bus) async {
    // Subscribe to all events for auditing
    bus.allEvents.listen((e) => _log.add('${e.runtimeType}@${e.sourceModuleId}'));
  }

  @override
  Future<void> onModuleReady(MicroModule module) async {
    _log.add('MODULE_READY:${module.moduleId}');
  }

  @override
  Future<void> onError(Object error, StackTrace st,
      {String? moduleId, bool isFatal = false}) async {
    _log.add('ERROR:$moduleId:$error');
  }

  List<String> get auditLog => List.unmodifiable(_log);
}
```
