import '../contracts/module_contract.dart';
import '../injection/global_injector.dart';
import '../events/event_bus.dart';
import '../utils/module_logger.dart';
import 'plugin_contract.dart';

/// Manages the lifecycle of all [MicroPlugin]s.
///
/// Plugins are initialized in two phases:
/// 1. **Before modules** — plugins with [MicroPlugin.initializeBeforeModules] = true
/// 2. **After modules** — all remaining plugins
class PluginRegistry {
  final GlobalInjector _globalInjector;
  final ModuleEventBus _eventBus;
  final _logger = ModuleLogger('PluginRegistry');

  final Map<String, MicroPlugin> _plugins = {};
  bool _disposed = false;

  PluginRegistry({
    required GlobalInjector globalInjector,
    required ModuleEventBus eventBus,
  })  : _globalInjector = globalInjector,
        _eventBus = eventBus;

  // ─── Initialization ────────────────────────────────────────────────────────

  /// Initialize plugins. Call with [beforeModules] = true then false.
  ///
  /// All plugins in [plugins] are initialized regardless of their
  /// [MicroPlugin.initializeBeforeModules] flag — the caller is responsible
  /// for passing the correct subset for each phase.
  Future<void> initializeAll(
    List<MicroPlugin> plugins, {
    required bool beforeModules,
  }) async {
    final targets = List<MicroPlugin>.from(plugins)
      ..sort((a, b) => b.priority.compareTo(a.priority));

    for (final plugin in targets) {
      await _initPlugin(plugin);
    }
  }

  Future<void> _initPlugin(MicroPlugin plugin) async {
    if (_plugins.containsKey(plugin.pluginId)) return;

    _logger.debug('  ↳ Initializing plugin: ${plugin.pluginName}');
    final sw = Stopwatch()..start();

    try {
      await plugin.initialize(_globalInjector, _eventBus);
      _plugins[plugin.pluginId] = plugin;
      sw.stop();
      _logger.info(
          '✅ Plugin ${plugin.pluginName} ready (${sw.elapsedMilliseconds}ms)');
    } catch (e, st) {
      _logger.error(
          '❌ Plugin ${plugin.pluginName} failed to initialize: $e',
          error: e, stackTrace: st);
      // Plugin failures are non-fatal — app continues
    }
  }

  // ─── Hooks ─────────────────────────────────────────────────────────────────

  Future<void> notifyModulesReady(List<String> moduleIds) async {
    for (final plugin in _plugins.values) {
      try {
        await plugin.onAllModulesReady(moduleIds);
      } catch (e, st) {
        _logger.error(
            'Plugin ${plugin.pluginId}.onAllModulesReady error: $e',
            error: e, stackTrace: st);
      }
    }
  }

  Future<void> notifyModuleRegistered(MicroModule module) async {
    for (final plugin in _plugins.values) {
      try {
        await plugin.onModuleRegistered(module);
      } catch (e, st) {
        _logger.error(
            'Plugin ${plugin.pluginId}.onModuleRegistered error: $e',
            error: e, stackTrace: st);
      }
    }
  }

  Future<void> notifyModuleReady(MicroModule module) async {
    for (final plugin in _plugins.values) {
      try {
        await plugin.onModuleReady(module);
      } catch (e, st) {
        _logger.error(
            'Plugin ${plugin.pluginId}.onModuleReady error: $e',
            error: e, stackTrace: st);
      }
    }
  }

  Future<void> notifyModuleDisposed(String moduleId) async {
    for (final plugin in _plugins.values) {
      try {
        await plugin.onModuleDisposed(moduleId);
      } catch (e, st) {
        _logger.error(
            'Plugin ${plugin.pluginId}.onModuleDisposed error: $e',
            error: e, stackTrace: st);
      }
    }
  }

  Future<void> notifyError(
    Object error,
    StackTrace stackTrace, {
    String? moduleId,
    bool isFatal = false,
  }) async {
    for (final plugin in _plugins.values) {
      try {
        await plugin.onError(
          error,
          stackTrace,
          moduleId: moduleId,
          isFatal: isFatal,
        );
      } catch (e, st) {
        _logger.error(
            'Plugin ${plugin.pluginId}.onError handler failed: $e',
            error: e, stackTrace: st);
      }
    }
  }

  // ─── Accessors ─────────────────────────────────────────────────────────────

  /// Get a registered plugin by ID and type.
  T? getPlugin<T extends MicroPlugin>(String pluginId) {
    final p = _plugins[pluginId];
    if (p is! T) return null;
    return p;
  }

  /// Get the first registered plugin of type [T].
  T? getPluginOfType<T extends MicroPlugin>() {
    for (final p in _plugins.values) {
      if (p is T) return p;
    }
    return null;
  }

  bool hasPlugin(String pluginId) => _plugins.containsKey(pluginId);

  List<String> get pluginIds => List.unmodifiable(_plugins.keys);

  // ─── Dispose ───────────────────────────────────────────────────────────────

  Future<void> dispose() async {
    if (_disposed) return;
    for (final plugin in _plugins.values) {
      try {
        await plugin.dispose();
      } catch (e, st) {
        _logger.error('Error disposing plugin ${plugin.pluginId}: $e',
            error: e, stackTrace: st);
      }
    }
    _plugins.clear();
    _disposed = true;
  }
}
