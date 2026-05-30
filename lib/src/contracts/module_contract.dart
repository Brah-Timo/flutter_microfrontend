import 'package:meta/meta.dart';
import '../injection/module_injector.dart';

/// The foundational contract every module in the system must implement.
///
/// [MicroModule] defines the full lifecycle of any feature unit:
/// **register → init → ready → pause/resume → dispose**
///
/// ## Minimal implementation
/// ```dart
/// class AuthModule extends MicroModule {
///   @override String get moduleId => 'auth';
///   @override String get moduleName => 'Authentication';
/// }
/// ```
///
/// ## With routes and events
/// ```dart
/// class ShopModule extends MicroModule
///     with RoutableModule, EventAwareModule {
///   @override String get moduleId => 'shop';
///   @override String get moduleName => 'Shop';
///   @override List<String> get dependencies => ['auth'];
///   // ...
/// }
/// ```
abstract class MicroModule {
  // ─── Identity ──────────────────────────────────────────────────────────────

  /// Unique identifier for this module across the entire system.
  /// Must be stable (no changes between app versions) and URL-safe.
  String get moduleId;

  /// Human-readable display name used in logging and debug UIs.
  String get moduleName;

  /// Semantic version of this module. Used for compatibility checks.
  String get version => '1.0.0';

  /// Short description of what this module provides.
  String get description => '';

  // ─── Dependencies ──────────────────────────────────────────────────────────

  /// List of [moduleId]s this module depends on.
  ///
  /// The registry guarantees all dependencies are fully initialized
  /// before [onInit] is called on this module.
  ///
  /// Circular dependencies are detected at startup and throw a
  /// [CircularDependencyException].
  List<String> get dependencies => const [];

  // ─── Loading Behavior ──────────────────────────────────────────────────────

  /// Whether this module should be loaded eagerly at app startup.
  ///
  /// Set to `true` for critical modules (auth, core services).
  /// Defaults to `false` — prefer lazy loading whenever possible.
  bool get isEager => false;

  /// Loading priority within the same dependency level.
  /// Higher values are initialized first.
  int get loadPriority => 0;

  // ─── Lifecycle Callbacks ───────────────────────────────────────────────────

  /// Called when the module is registered with the [ModuleRegistry].
  ///
  /// **Primary use:** register services into the module's DI container.
  ///
  /// ```dart
  /// @override
  /// Future<void> onRegister(ModuleInjector injector) async {
  ///   injector.registerLazySingleton<AuthService>(
  ///     () => FirebaseAuthService(),
  ///   );
  /// }
  /// ```
  @mustCallSuper
  Future<void> onRegister(ModuleInjector injector) async {}

  /// Called after ALL modules have been registered.
  ///
  /// **Primary use:** cross-module initialization (e.g., subscribe to another
  /// module's events, set up cross-module state).
  @mustCallSuper
  Future<void> onInit() async {}

  /// Called when the application enters the background.
  @mustCallSuper
  Future<void> onPause() async {}

  /// Called when the application returns to the foreground.
  @mustCallSuper
  Future<void> onResume() async {}

  /// Called when the module is unregistered or the app is closing.
  ///
  /// **Primary use:** cancel subscriptions, close streams, free resources.
  @mustCallSuper
  Future<void> onDispose() async {}

  /// Called when an unhandled error occurs within this module.
  ///
  /// Return `true` if the error was handled (suppresses further propagation).
  /// Return `false` to let the error propagate to the global error handler.
  Future<bool> onError(Object error, StackTrace stackTrace) async => false;

  // ─── Equality ──────────────────────────────────────────────────────────────

  @override
  String toString() => 'MicroModule($moduleId v$version)';

  @override
  bool operator ==(Object other) =>
      other is MicroModule && other.moduleId == moduleId;

  @override
  int get hashCode => moduleId.hashCode;
}

// ─── Module Lifecycle State ──────────────────────────────────────────────────

/// Tracks the current lifecycle state of a registered module.
enum ModuleLifecycleState {
  /// Registered in the registry, initialization not yet started.
  registered,

  /// Currently running [onRegister] or [onInit].
  initializing,

  /// Fully initialized and ready to serve requests.
  ready,

  /// Temporarily suspended (app in background).
  paused,

  /// Currently running [onDispose].
  disposing,

  /// Disposed. Instance is no longer usable.
  disposed,

  /// An error occurred during initialization or runtime.
  error,
}

// ─── Lifecycle Event ─────────────────────────────────────────────────────────

/// Emitted on [ModuleRegistry.lifecycleStream] whenever a module
/// changes its lifecycle state.
class ModuleLifecycleEvent {
  final String moduleId;
  final ModuleLifecycleState state;
  final DateTime timestamp;
  final Object? error;

  ModuleLifecycleEvent({
    required this.moduleId,
    required this.state,
    this.error,
  }) : timestamp = DateTime.now();

  @override
  String toString() =>
      'ModuleLifecycleEvent(module: $moduleId, state: $state)';
}

// ─── Exceptions ──────────────────────────────────────────────────────────────

/// Thrown when attempting to cast a module to an incompatible type.
class ModuleTypeMismatchException implements Exception {
  final String message;
  const ModuleTypeMismatchException(this.message);
  @override
  String toString() => 'ModuleTypeMismatchException: $message';
}

/// Thrown when a required dependency module is not found in the registry.
class ModuleDependencyNotFoundException implements Exception {
  final String message;
  const ModuleDependencyNotFoundException(this.message);
  @override
  String toString() => 'ModuleDependencyNotFoundException: $message';
}

/// Thrown when a module with the same ID is registered twice.
class DuplicateModuleException implements Exception {
  final String message;
  const DuplicateModuleException(this.message);
  @override
  String toString() => 'DuplicateModuleException: $message';
}

/// Thrown during module validation (missing ID, name, etc.).
class ModuleValidationException implements Exception {
  final String message;
  const ModuleValidationException(this.message);
  @override
  String toString() => 'ModuleValidationException: $message';
}
