import 'dart:async';
import '../contracts/module_contract.dart';
import '../lazy/deferred_module.dart';
import '../lazy/preload_strategy.dart';
import '../utils/module_logger.dart';

/// Manages loading and unloading of [DeferredModule]s.
///
/// Implements multiple [PreloadStrategy] policies and tracks loading metrics.
class ModuleLoader {
  final _logger = ModuleLogger('ModuleLoader');
  final Map<String, DeferredModule> _deferredModules = {};
  final Map<String, _LoadMetrics> _metrics = {};
  Timer? _idleTimer;

  // ─── Registration ──────────────────────────────────────────────────────────

  /// Registers a [DeferredModule] for deferred loading.
  void register(DeferredModule module) {
    _deferredModules[module.moduleId] = module;
    _metrics[module.moduleId] = _LoadMetrics();
    _logger.debug('Registered deferred module: ${module.moduleName}');
  }

  // ─── Trigger Policies ──────────────────────────────────────────────────────

  /// Notify loader that the app finished initializing all eager modules.
  Future<void> onAppReady() async {
    await _triggerStrategy(PreloadStrategy.afterAppReady);
    _scheduleIdleLoad();
  }

  /// Notify loader that navigation is about to occur to [path].
  Future<MicroModule?> onNavigateTo(String path) async {
    for (final module in _deferredModules.values) {
      if (!module.isLoaded &&
          module.preloadStrategy == PreloadStrategy.onFirstNavigation) {
        final routes = _getModuleRoutes(module);
        if (routes.any((r) => path.startsWith(r))) {
          return _loadModule(module);
        }
      }
    }
    return null;
  }

  /// Explicitly load a module by its ID.
  Future<MicroModule?> loadById(String moduleId) async {
    final module = _deferredModules[moduleId];
    if (module == null) return null;
    return _loadModule(module);
  }

  /// Unload a module to free memory.
  Future<void> unloadById(String moduleId) async {
    final module = _deferredModules[moduleId];
    if (module == null) return;
    await module.unload();
    _logger.info('Unloaded module: ${module.moduleName}');
  }

  // ─── Load Status ───────────────────────────────────────────────────────────

  bool isLoaded(String moduleId) =>
      _deferredModules[moduleId]?.isLoaded ?? false;

  bool isLoading(String moduleId) =>
      _deferredModules[moduleId]?.isLoading ?? false;

  Map<String, LoadStatus> get statusMap => {
        for (final entry in _deferredModules.entries)
          entry.key: LoadStatus(
            moduleId: entry.key,
            moduleName: entry.value.moduleName,
            isLoaded: entry.value.isLoaded,
            isLoading: entry.value.isLoading,
            strategy: entry.value.preloadStrategy,
            metrics: _metrics[entry.key],
          ),
      };

  // ─── Private ───────────────────────────────────────────────────────────────

  Future<MicroModule?> _loadModule(DeferredModule module) async {
    if (module.isLoaded) return module.loadedModule;
    final metrics = _metrics[module.moduleId]!;
    metrics.attempts++;
    metrics.lastAttemptAt = DateTime.now();
    final sw = Stopwatch()..start();
    try {
      final loaded = await module.load();
      sw.stop();
      metrics.loadDurationMs = sw.elapsedMilliseconds;
      metrics.loadedAt = DateTime.now();
      _logger.info(
          '✅ Loaded ${module.moduleName} in ${sw.elapsedMilliseconds}ms');
      return loaded;
    } catch (e, st) {
      sw.stop();
      metrics.failureCount++;
      _logger.error('❌ Failed to load ${module.moduleName}: $e', error: e, stackTrace: st);
      return null;
    }
  }

  Future<void> _triggerStrategy(PreloadStrategy strategy) async {
    final targets = _deferredModules.values
        .where((m) => !m.isLoaded && m.preloadStrategy == strategy)
        .toList()
      ..sort((a, b) => b.loadPriority.compareTo(a.loadPriority));

    for (final module in targets) {
      await _loadModule(module);
    }
  }

  void _scheduleIdleLoad() {
    _idleTimer = Timer(const Duration(seconds: 3), () async {
      await _triggerStrategy(PreloadStrategy.whenIdle);
    });
  }

  List<String> _getModuleRoutes(DeferredModule module) {
    // Placeholder — real implementation queries RouteRegistration
    return [];
  }

  void dispose() {
    _idleTimer?.cancel();
  }
}

// ─── Supporting Types ─────────────────────────────────────────────────────────

class LoadStatus {
  final String moduleId;
  final String moduleName;
  final bool isLoaded;
  final bool isLoading;
  final PreloadStrategy strategy;
  final _LoadMetrics? metrics;

  const LoadStatus({
    required this.moduleId,
    required this.moduleName,
    required this.isLoaded,
    required this.isLoading,
    required this.strategy,
    this.metrics,
  });
}

class _LoadMetrics {
  int attempts = 0;
  int failureCount = 0;
  int? loadDurationMs;
  DateTime? lastAttemptAt;
  DateTime? loadedAt;
}
