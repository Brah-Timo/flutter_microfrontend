import 'package:get_it/get_it.dart';
import 'global_injector.dart';

/// A scoped DI container for a single [MicroModule].
///
/// Each module gets its own isolated [GetIt] instance. This means:
/// - Services registered in module A are NOT visible in module B
/// - You can register the same type in two different modules without conflict
/// - Module disposal automatically cleans up all its registered services
///
/// When looking up a service, the resolution order is:
/// 1. **Module-local** container (registered via [ModuleInjector])
/// 2. **Global** container (registered via [GlobalInjector])
///
/// ```dart
/// @override
/// Future<void> onRegister(ModuleInjector injector) async {
///   // Local to this module only
///   injector.registerLazySingleton<AuthRepository>(
///     () => AuthRepositoryImpl(
///       http: injector.get<HttpClient>(),       // from GlobalInjector
///       storage: injector.get<LocalStorage>(),  // from GlobalInjector
///     ),
///   );
///
///   // Expose a service globally so other modules can use it
///   injector.exposeGlobally<AuthService>(
///     () => FirebaseAuthService(),
///   );
/// }
/// ```
class ModuleInjector {
  final String moduleId;
  final GlobalInjector _global;
  final GetIt _local = GetIt.asNewInstance();
  bool _disposed = false;

  ModuleInjector({
    required this.moduleId,
    required GlobalInjector globalInjector,
  }) : _global = globalInjector;

  // ─── Local Registration ────────────────────────────────────────────────────

  /// Register a singleton instance locally (module-scoped).
  void registerSingleton<T extends Object>(
    T instance, {
    String? instanceName,
    DisposalFunc<T>? dispose,
  }) {
    _assertAlive();
    _local.registerSingleton<T>(instance,
        instanceName: instanceName, dispose: dispose);
  }

  /// Register a factory locally (new instance per [get] call).
  void registerFactory<T extends Object>(
    T Function() factory, {
    String? instanceName,
  }) {
    _assertAlive();
    _local.registerFactory<T>(factory, instanceName: instanceName);
  }

  /// Register a lazy singleton locally (created on first [get]).
  void registerLazySingleton<T extends Object>(
    T Function() factory, {
    String? instanceName,
    DisposalFunc<T>? dispose,
  }) {
    _assertAlive();
    _local.registerLazySingleton<T>(factory,
        instanceName: instanceName, dispose: dispose);
  }

  /// Register an async singleton locally.
  void registerSingletonAsync<T extends Object>(
    Future<T> Function() asyncFactory, {
    String? instanceName,
  }) {
    _assertAlive();
    _local.registerSingletonAsync<T>(asyncFactory,
        instanceName: instanceName);
  }

  // ─── Global Exposure ───────────────────────────────────────────────────────

  /// Register a service both locally AND globally.
  ///
  /// Use this to make module services available to other modules.
  void exposeGlobally<T extends Object>(
    T Function() factory, {
    String? instanceName,
  }) {
    _assertAlive();
    final instance = factory();
    _local.registerSingleton<T>(instance, instanceName: instanceName);
    if (!_global.isRegistered<T>(instanceName: instanceName)) {
      _global.registerSingleton<T>(instance, instanceName: instanceName);
    }
  }

  // ─── Retrieval ─────────────────────────────────────────────────────────────

  /// Get a service. Checks local container first, then global.
  T get<T extends Object>({String? instanceName}) {
    _assertAlive();
    if (_local.isRegistered<T>(instanceName: instanceName)) {
      return _local.get<T>(instanceName: instanceName);
    }
    return _global.get<T>(instanceName: instanceName);
  }

  /// Get an async-registered service. Checks local first, then global.
  Future<T> getAsync<T extends Object>({String? instanceName}) {
    _assertAlive();
    if (_local.isRegistered<T>(instanceName: instanceName)) {
      return _local.getAsync<T>(instanceName: instanceName);
    }
    return _global.getAsync<T>(instanceName: instanceName);
  }

  /// Returns true if type [T] is registered locally or globally.
  bool isRegistered<T extends Object>({String? instanceName}) {
    return _local.isRegistered<T>(instanceName: instanceName) ||
        _global.isRegistered<T>(instanceName: instanceName);
  }

  /// Try get — returns null if not registered anywhere.
  T? tryGet<T extends Object>({String? instanceName}) {
    if (!isRegistered<T>(instanceName: instanceName)) return null;
    return get<T>(instanceName: instanceName);
  }

  // ─── Lifecycle ─────────────────────────────────────────────────────────────

  void dispose() {
    if (!_disposed) {
      _local.reset(dispose: true);
      _disposed = true;
    }
  }

  bool get isDisposed => _disposed;

  void _assertAlive() {
    assert(
      !_disposed,
      'ModuleInjector for "$moduleId" has been disposed.',
    );
  }
}

/// Function type for custom disposal logic.
typedef DisposalFunc<T> = void Function(T instance);
