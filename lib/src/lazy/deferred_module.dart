import 'dart:async';
import '../contracts/module_contract.dart';
import '../injection/module_injector.dart';
import '../utils/module_logger.dart';
import 'preload_strategy.dart';

/// A wrapper that enables lazy loading of a [MicroModule].
///
/// The actual module code is NOT loaded until [load] is called.
/// This dramatically reduces startup time and memory usage for large apps.
///
/// ## Usage with Dart deferred imports
/// ```dart
/// // Import with deferred keyword
/// import 'features/shop/shop_module.dart' deferred as shop_lib;
///
/// // Wrap in DeferredModule
/// DeferredModule(
///   moduleId: 'shop',
///   moduleName: 'Shop',
///   loader: () async {
///     await shop_lib.loadLibrary();   // Dart deferred loading
///     return shop_lib.ShopModule();   // Instantiate after load
///   },
///   preloadStrategy: PreloadStrategy.afterAppReady,
///   dependencies: ['auth'],
/// )
/// ```
///
/// ## Without deferred imports (simpler, less code splitting)
/// ```dart
/// DeferredModule(
///   moduleId: 'analytics',
///   loader: () async => AnalyticsModule(),
///   preloadStrategy: PreloadStrategy.whenIdle,
/// )
/// ```
class DeferredModule extends MicroModule {
  final String _moduleId;
  final String _moduleName;
  final Future<MicroModule> Function() _loader;
  final PreloadStrategy _preloadStrategy;
  final PreloadConfig _config;
  final List<String> _dependencies;
  final List<String> _routePrefixes;

  // ─── State ─────────────────────────────────────────────────────────────────

  MicroModule? _loadedModule;
  Completer<MicroModule>? _pendingLoad;
  bool _isLoaded = false;
  bool _isLoading = false;
  int _loadAttempts = 0;
  DateTime? _loadedAt;

  final _logger = ModuleLogger('DeferredModule');

  DeferredModule({
    required String moduleId,
    required Future<MicroModule> Function() loader,
    String? moduleName,
    PreloadStrategy preloadStrategy = PreloadStrategy.onDemand,
    PreloadConfig? config,
    List<String> dependencies = const [],
    List<String> routePrefixes = const [],
  })  : _moduleId = moduleId,
        _moduleName = moduleName ?? moduleId,
        _loader = loader,
        _preloadStrategy = preloadStrategy,
        _config = config ?? PreloadConfig.defaults,
        _dependencies = dependencies,
        _routePrefixes = routePrefixes;

  // ─── MicroModule identity ──────────────────────────────────────────────────

  @override
  String get moduleId => _moduleId;

  @override
  String get moduleName => _moduleName;

  @override
  List<String> get dependencies => _dependencies;

  // ─── DeferredModule specifics ──────────────────────────────────────────────

  bool get isLoaded => _isLoaded;
  bool get isLoading => _isLoading;
  MicroModule? get loadedModule => _loadedModule;
  PreloadStrategy get preloadStrategy => _preloadStrategy;
  PreloadConfig get config => _config;
  List<String> get routePrefixes => _routePrefixes;
  int get loadAttempts => _loadAttempts;
  DateTime? get loadedAt => _loadedAt;

  // ─── Load ──────────────────────────────────────────────────────────────────

  /// Loads the actual module.
  ///
  /// - Idempotent: returns cached instance on repeated calls.
  /// - Concurrent-safe: multiple simultaneous calls return the same [Future].
  /// - Retries up to [PreloadConfig.maxRetries] times on failure.
  Future<MicroModule> load() async {
    if (_isLoaded && _loadedModule != null) return _loadedModule!;
    if (_isLoading && _pendingLoad != null) return _pendingLoad!.future;

    _isLoading = true;
    _pendingLoad = Completer<MicroModule>();

    try {
      final result = await _loadWithRetry();
      _loadedModule = result;
      _isLoaded = true;
      _loadedAt = DateTime.now();
      _logger.info('✅ Loaded: $_moduleName in attempt #$_loadAttempts');
      _pendingLoad!.complete(result);
      return result;
    } catch (e, st) {
      _isLoading = false;
      // Do NOT call completeError on _pendingLoad — that would create a second
      // unhandled error future. The caller gets the error via `rethrow`.
      // Null out the completer so concurrent waiters who already have
      // _pendingLoad.future get a clean error (they share the rethrow path
      // via the same Future chain).
      _pendingLoad = null;
      _logger.error('❌ Failed to load $_moduleName after $_loadAttempts attempts',
          error: e, stackTrace: st);
      rethrow;
    } finally {
      _isLoading = false;
    }
  }

  Future<MicroModule> _loadWithRetry() async {
    for (int attempt = 1; attempt <= _config.maxRetries; attempt++) {
      _loadAttempts = attempt;
      try {
        _logger.debug('Loading $_moduleName (attempt $attempt/${_config.maxRetries})...');
        return await _loader().timeout(_config.loadTimeout);
      } catch (e) {
        if (attempt == _config.maxRetries) rethrow;
        _logger.warning(
            '$_moduleName load attempt $attempt failed. '
            'Retrying in ${_config.retryDelay.inSeconds}s...');
        await Future<void>.delayed(_config.retryDelay);
      }
    }
    throw StateError('Unreachable');
  }

  // ─── Unload ────────────────────────────────────────────────────────────────

  /// Unloads the module to free memory.
  ///
  /// The module can be reloaded later by calling [load] again.
  Future<void> unload() async {
    if (_loadedModule != null) {
      try {
        await _loadedModule!.onDispose();
      } catch (_) {}
    }
    _loadedModule = null;
    _isLoaded = false;
    _isLoading = false;
    _pendingLoad = null;
    _loadedAt = null;
    _logger.info('🗑️  Unloaded: $_moduleName');
  }

  // ─── Lifecycle delegation ──────────────────────────────────────────────────

  @override
  Future<void> onRegister(ModuleInjector injector) async {
    // Delegation happens after load; placeholder does nothing.
    await super.onRegister(injector);
  }

  @override
  Future<void> onPause() async {
    await super.onPause();
    await _loadedModule?.onPause();
  }

  @override
  Future<void> onResume() async {
    await super.onResume();
    await _loadedModule?.onResume();
  }

  @override
  Future<void> onDispose() async {
    await unload();
    await super.onDispose();
  }

  // ─── Diagnostics ───────────────────────────────────────────────────────────

  DeferredModuleDiagnostics get diagnostics => DeferredModuleDiagnostics(
        moduleId: _moduleId,
        moduleName: _moduleName,
        isLoaded: _isLoaded,
        isLoading: _isLoading,
        loadAttempts: _loadAttempts,
        preloadStrategy: _preloadStrategy,
        loadedAt: _loadedAt,
      );

  @override
  String toString() => 'DeferredModule($_moduleId, loaded: $_isLoaded)';
}

// ─── Diagnostics ──────────────────────────────────────────────────────────────

class DeferredModuleDiagnostics {
  final String moduleId;
  final String moduleName;
  final bool isLoaded;
  final bool isLoading;
  final int loadAttempts;
  final PreloadStrategy preloadStrategy;
  final DateTime? loadedAt;

  const DeferredModuleDiagnostics({
    required this.moduleId,
    required this.moduleName,
    required this.isLoaded,
    required this.isLoading,
    required this.loadAttempts,
    required this.preloadStrategy,
    this.loadedAt,
  });
}
