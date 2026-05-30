import 'package:get_it/get_it.dart';

/// The global dependency injection container shared across all modules.
///
/// Services registered here are accessible from any module's [ModuleInjector].
/// Only register truly shared infrastructure services:
/// - HTTP clients
/// - Local storage
/// - Authentication tokens
/// - App configuration
///
/// **Do NOT register feature-specific services here** — those belong in their
/// module's [ModuleInjector].
///
/// ```dart
/// // In MicrofrontendApp.sharedServices callback:
/// sharedServices: (injector) {
///   injector.registerSingleton<HttpClient>(
///     DioClient(baseUrl: Env.apiUrl),
///   );
///   injector.registerSingleton<LocalStorage>(HiveStorage());
///   injector.registerSingleton<Config>(AppConfig.fromEnv());
/// },
/// ```
class GlobalInjector {
  final GetIt _container = GetIt.asNewInstance();
  bool _disposed = false;

  // ─── Registration ──────────────────────────────────────────────────────────

  /// Register an already-constructed instance as a singleton.
  void registerSingleton<T extends Object>(
    T instance, {
    String? instanceName,
  }) {
    _assertAlive();
    _container.registerSingleton<T>(instance, instanceName: instanceName);
  }

  /// Register a factory function. Each [get] call creates a new instance.
  void registerFactory<T extends Object>(
    T Function() factory, {
    String? instanceName,
  }) {
    _assertAlive();
    _container.registerFactory<T>(factory, instanceName: instanceName);
  }

  /// Register a lazy singleton. Created on first [get] call.
  void registerLazySingleton<T extends Object>(
    T Function() factory, {
    String? instanceName,
  }) {
    _assertAlive();
    _container.registerLazySingleton<T>(factory,
        instanceName: instanceName);
  }

  /// Register an asynchronously-created singleton.
  void registerSingletonAsync<T extends Object>(
    Future<T> Function() asyncFactory, {
    String? instanceName,
  }) {
    _assertAlive();
    _container.registerSingletonAsync<T>(asyncFactory,
        instanceName: instanceName);
  }

  // ─── Retrieval ─────────────────────────────────────────────────────────────

  /// Retrieve a registered service synchronously.
  T get<T extends Object>({String? instanceName}) {
    _assertAlive();
    return _container.get<T>(instanceName: instanceName);
  }

  /// Retrieve an asynchronously-registered service.
  Future<T> getAsync<T extends Object>({String? instanceName}) {
    _assertAlive();
    return _container.getAsync<T>(instanceName: instanceName);
  }

  /// Returns `true` if a service of type [T] is registered.
  bool isRegistered<T extends Object>({String? instanceName}) {
    return _container.isRegistered<T>(instanceName: instanceName);
  }

  /// Try to get a service, returning null if not registered.
  T? tryGet<T extends Object>({String? instanceName}) {
    if (!isRegistered<T>(instanceName: instanceName)) return null;
    return get<T>(instanceName: instanceName);
  }

  // ─── Lifecycle ─────────────────────────────────────────────────────────────

  void dispose() {
    if (!_disposed) {
      _container.reset(dispose: true);
      _disposed = true;
    }
  }

  bool get isDisposed => _disposed;

  void _assertAlive() {
    assert(!_disposed,
        'GlobalInjector has been disposed. Do not use after dispose().');
  }
}
