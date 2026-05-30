import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../contracts/module_contract.dart';
import '../events/event_bus.dart';
import '../injection/global_injector.dart';
import '../plugins/plugin_contract.dart';
import '../plugins/plugin_registry.dart';
import '../navigation/module_router.dart';
import '../lazy/deferred_module.dart';
import '../core/module_loader.dart';
import '../utils/module_logger.dart';
import 'module_registry.dart';

/// The root widget that bootstraps the entire micro-frontend system.
///
/// Wrap your app with [MicrofrontendApp] as the very first widget.
/// It handles:
/// - Module registration and initialization (in dependency order)
/// - Plugin initialization
/// - Global dependency injection setup
/// - Event bus creation
/// - Router assembly from all module routes
/// - App lifecycle forwarding to all modules
///
/// ```dart
/// void main() {
///   runApp(
///     MicrofrontendApp(
///       modules: [
///         AuthModule(),        // eager (critical)
///         HomeModule(),        // eager
///         DeferredModule(      // lazy (loaded on demand)
///           moduleId: 'shop',
///           loader: () async => ShopModule(),
///         ),
///       ],
///       plugins: [
///         FirebaseAnalyticsPlugin(),
///         SentryPlugin(dsn: '...'),
///       ],
///       sharedServices: (injector) {
///         injector.registerSingleton<HttpClient>(
///           DioClient(baseUrl: Env.apiUrl),
///         );
///       },
///       onError: (e, st) => Sentry.captureException(e, stackTrace: st),
///     ),
///   );
/// }
/// ```
class MicrofrontendApp extends StatefulWidget {
  /// All modules (eager and deferred) that compose the application.
  final List<MicroModule> modules;

  /// Cross-cutting plugins (analytics, crash reporting, feature flags, etc.).
  final List<MicroPlugin> plugins;

  /// Callback to register shared services visible to all modules.
  final void Function(GlobalInjector injector)? sharedServices;

  /// Global error handler for unhandled exceptions during initialization.
  final void Function(Object error, StackTrace stackTrace)? onError;

  /// Widget displayed while the system is initializing.
  final Widget? splashWidget;

  /// Widget builder displayed when initialization fails.
  final Widget Function(Object error, VoidCallback retry)? errorWidget;

  /// Additional GoRouter configuration (observers, redirect, etc.).
  final ModuleRouterConfig? routerConfig;

  /// Enables verbose debug output in [ModuleLogger].
  final bool debugMode;

  /// App title (forwarded to [MaterialApp]).
  final String title;

  /// App theme.
  final ThemeData? theme;

  /// App dark theme.
  final ThemeData? darkTheme;

  /// Theme mode.
  final ThemeMode themeMode;

  const MicrofrontendApp({
    super.key,
    required this.modules,
    this.plugins = const [],
    this.sharedServices,
    this.onError,
    this.splashWidget,
    this.errorWidget,
    this.routerConfig,
    this.debugMode = false,
    this.title = '',
    this.theme,
    this.darkTheme,
    this.themeMode = ThemeMode.system,
  });

  @override
  State<MicrofrontendApp> createState() => _MicrofrontendAppState();

  /// Access the nearest [MicrofrontendApp] from the widget tree.
  static _MicrofrontendAppState of(BuildContext context) {
    return context.findAncestorStateOfType<_MicrofrontendAppState>()!;
  }
}

class _MicrofrontendAppState extends State<MicrofrontendApp>
    with WidgetsBindingObserver {
  late final ModuleRegistry _registry;
  late final ModuleEventBus _eventBus;
  late final GlobalInjector _globalInjector;
  late final PluginRegistry _pluginRegistry;
  late final ModuleLoader _loader;
  ModuleRouter? _router;

  final _logger = ModuleLogger('MicrofrontendApp');

  _AppInitState _initState = _AppInitState.initializing;
  Object? _initError;

  // ─── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    ModuleLogger.debugMode = widget.debugMode;
    WidgetsBinding.instance.addObserver(this);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      _logger.info('🚀 Bootstrapping MicrofrontendApp...');
      final sw = Stopwatch()..start();

      // 1. Global injector & shared services
      _globalInjector = GlobalInjector();
      widget.sharedServices?.call(_globalInjector);

      // 2. Event bus
      _eventBus = ModuleEventBus();

      // 3. Plugin registry (runs before modules)
      _pluginRegistry = PluginRegistry(
        globalInjector: _globalInjector,
        eventBus: _eventBus,
      );
      await _pluginRegistry.initializeAll(
        widget.plugins,
        beforeModules: true,
      );

      // 4. Module registry
      _registry = ModuleRegistry.instance;
      await _registry.initialize(
        modules: widget.modules,
        globalInjector: _globalInjector,
        eventBus: _eventBus,
      );

      // 5. Post-module plugins
      await _pluginRegistry.initializeAll(
        widget.plugins,
        beforeModules: false,
      );
      await _pluginRegistry.notifyModulesReady(_registry.registeredModuleIds);

      // 6. Deferred module loader
      _loader = ModuleLoader();
      for (final m in widget.modules.whereType<DeferredModule>()) {
        _loader.register(m);
      }
      await _loader.onAppReady();

      // 7. Build router
      _router = ModuleRouter(
        registry: _registry,
        config: widget.routerConfig,
      );

      sw.stop();
      _logger.info(
          '✅ Bootstrap complete in ${sw.elapsedMilliseconds}ms | '
          '${widget.modules.length} modules | ${widget.plugins.length} plugins');

      if (mounted) setState(() => _initState = _AppInitState.ready);
    } catch (e, st) {
      _logger.error('❌ Bootstrap failed: $e', error: e, stackTrace: st);
      widget.onError?.call(e, st);
      if (mounted) {
        setState(() {
          _initState = _AppInitState.error;
          _initError = e;
        });
      }
    }
  }

  Future<void> _retry() async {
    setState(() {
      _initState = _AppInitState.initializing;
      _initError = null;
    });
    await _bootstrap();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
        _registry.pauseAll();
      case AppLifecycleState.resumed:
        _registry.resumeAll();
      case AppLifecycleState.detached:
        _cleanup();
      default:
        break;
    }
  }

  Future<void> _cleanup() async {
    await _registry.dispose();
    await _eventBus.dispose();
    _globalInjector.dispose();
    _loader.dispose();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cleanup();
    super.dispose();
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return switch (_initState) {
      _AppInitState.initializing => _buildSplash(),
      _AppInitState.error => _buildError(),
      _AppInitState.ready => _buildApp(),
    };
  }

  Widget _buildSplash() {
    return widget.splashWidget ??
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 20),
                  Text(
                    'Initializing ${widget.title}...',
                    style: const TextStyle(
                        fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        );
  }

  Widget _buildError() {
    final error = _initError ?? 'Unknown error';
    return widget.errorWidget?.call(error, _retry) ??
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    const Text(
                      'Initialization Failed',
                      style: TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      error.toString(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _retry,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
  }

  Widget _buildApp() {
    return MaterialApp.router(
      title: widget.title,
      theme: widget.theme,
      darkTheme: widget.darkTheme,
      themeMode: widget.themeMode,
      routerConfig: _router!.goRouter,
      debugShowCheckedModeBanner: widget.debugMode && kDebugMode,
    );
  }

  // ─── Public API ────────────────────────────────────────────────────────────

  /// Access the module registry.
  ModuleRegistry get registry => _registry;

  /// Access the event bus.
  ModuleEventBus get eventBus => _eventBus;

  /// Access the global injector.
  GlobalInjector get globalInjector => _globalInjector;

  /// Access the module loader.
  ModuleLoader get loader => _loader;
}

enum _AppInitState { initializing, ready, error }
