import 'dart:async';
import 'package:go_router/go_router.dart';
import '../contracts/module_contract.dart';
import '../contracts/routable_module.dart';
import '../contracts/service_module.dart';
import '../contracts/event_aware_module.dart';
import '../injection/module_injector.dart';
import '../injection/global_injector.dart';
import '../events/event_bus.dart';
import '../lazy/deferred_module.dart';
import '../navigation/route_registration.dart';
import '../utils/module_logger.dart';
import '../utils/module_validator.dart';
import '../utils/dependency_graph.dart';
import 'module_lifecycle.dart';

/// The central registry and orchestrator for all [MicroModule]s.
///
/// Responsibilities:
/// - Register and initialize modules in dependency order
/// - Manage module lifecycle (init → pause → resume → dispose)
/// - Provide access to modules by ID
/// - Collect all routes from [RoutableModule]s
/// - Track lifecycle states and emit lifecycle events
///
/// This is a singleton — access via [ModuleRegistry.instance].
class ModuleRegistry {
  ModuleRegistry._();
  static final ModuleRegistry _instance = ModuleRegistry._();

  /// The global singleton instance.
  static ModuleRegistry get instance => _instance;

  // ─── Internal State ────────────────────────────────────────────────────────

  final Map<String, MicroModule> _modules = {};
  final Map<String, ModuleLifecycleManager> _lifecycles = {};
  final Map<String, ModuleInjector> _injectors = {};

  // Non-final so it can be recreated after dispose() — this class is a
  // process-lifetime singleton and must remain usable across test setUp/tearDown.
  // sync: true → lifecycle events are delivered synchronously within _emit(),
  // so subscribers see them immediately without needing async gaps in tests.
  StreamController<ModuleLifecycleEvent> _lifecycleController =
      StreamController<ModuleLifecycleEvent>.broadcast(sync: true);

  final _logger = ModuleLogger('ModuleRegistry');
  final _validator = ModuleValidator();

  late GlobalInjector _globalInjector;
  late ModuleEventBus _eventBus;
  bool _initialized = false;

  // ─── Public Streams ────────────────────────────────────────────────────────

  /// Stream of lifecycle state changes for all modules.
  Stream<ModuleLifecycleEvent> get lifecycleStream =>
      _lifecycleController.stream;

  // ─── Initialization ────────────────────────────────────────────────────────

  /// Initialize the registry with the given modules.
  ///
  /// This method:
  /// 1. Validates all modules
  /// 2. Builds a dependency graph & checks for circular deps
  /// 3. Sorts modules in topological order
  /// 4. Registers each module (DI setup, event bus attachment)
  /// 5. Calls [MicroModule.onInit] on all modules
  Future<void> initialize({
    required List<MicroModule> modules,
    required GlobalInjector globalInjector,
    required ModuleEventBus eventBus,
  }) async {
    if (_initialized) {
      _logger.warning('Registry already initialized. Call dispose() first.');
      return;
    }

    _globalInjector = globalInjector;
    _eventBus = eventBus;

    _logger.info('🚀 Initializing ${modules.length} module(s)...');
    final sw = Stopwatch()..start();

    // 1. Validate
    for (final m in modules) {
      _validator.validate(m);
    }

    // 2. Separate eager and deferred modules
    final eagerModules =
        modules.whereType<MicroModule>().where((m) => m is! DeferredModule).toList();
    final deferredModules = modules.whereType<DeferredModule>().toList();

    // 3. Build dependency graph on eager modules
    final graph = DependencyGraph();
    graph.build(eagerModules);
    graph.checkForCircularDependencies();

    // 4. Topological sort
    final ordered = graph.getTopologicalOrder(eagerModules);

    // 5. Register each module
    for (final module in ordered) {
      await _registerModule(module);
    }

    // 6. Register deferred module placeholders
    for (final deferred in deferredModules) {
      _logger.debug('Registered deferred placeholder: ${deferred.moduleName}');
      _modules[deferred.moduleId] = deferred;
      _lifecycles[deferred.moduleId] =
          ModuleLifecycleManager(deferred.moduleId);
    }

    // 7. Call onInit on all eager modules
    for (final module in ordered) {
      await _callOnInit(module);
    }

    sw.stop();
    _initialized = true;
    _logger.info(
        '✅ Registry initialized in ${sw.elapsedMilliseconds}ms | '
        '${ordered.length} eager + ${deferredModules.length} deferred');
  }

  // ─── Module Registration ───────────────────────────────────────────────────

  Future<void> _registerModule(MicroModule module) async {
    final id = module.moduleId;

    if (_modules.containsKey(id)) {
      throw DuplicateModuleException(
          'Module "$id" is already registered. '
          'Each module ID must be unique.');
    }

    _logger.debug('  ↳ Registering ${module.moduleName} ($id)...');
    _emit(ModuleLifecycleEvent(
        moduleId: id, state: ModuleLifecycleState.registered));

    final lifecycle = ModuleLifecycleManager(id);
    lifecycle.transitionTo(ModuleLifecycleState.initializing);
    _lifecycles[id] = lifecycle;

    // Create scoped DI container for this module
    final injector = ModuleInjector(
      moduleId: id,
      globalInjector: _globalInjector,
    );
    _injectors[id] = injector;

    // Attach event bus if EventAwareModule
    if (module is EventAwareModule) {
      module.attachEventBus(_eventBus);
    }

    // Register global services first if ServiceModule
    if (module is ServiceModule &&
        module.registerGlobalServicesFirst) {
      await module.registerGlobalServices(injector);
    }

    // Module registers its own services
    await module.onRegister(injector);

    _modules[id] = module;
  }

  Future<void> _callOnInit(MicroModule module) async {
    final lifecycle = _lifecycles[module.moduleId]!;
    try {
      await module.onInit();
      lifecycle.transitionTo(ModuleLifecycleState.ready);
      _emit(ModuleLifecycleEvent(
          moduleId: module.moduleId, state: ModuleLifecycleState.ready));
      _logger.debug('  ✓ ${module.moduleName} ready '
          '(${lifecycle.diagnostics.initializationTime?.inMilliseconds}ms)');
    } catch (e, st) {
      lifecycle.transitionTo(ModuleLifecycleState.error,
          error: e, stackTrace: st);
      _emit(ModuleLifecycleEvent(
          moduleId: module.moduleId,
          state: ModuleLifecycleState.error,
          error: e));
      _logger.error('❌ ${module.moduleName} failed onInit: $e',
          error: e, stackTrace: st);
      rethrow;
    }
  }

  // ─── Dynamic Registration ──────────────────────────────────────────────────

  /// Registers a module dynamically at runtime (after app startup).
  ///
  /// Useful for feature modules loaded on demand. The module's dependencies
  /// must already be registered.
  Future<void> registerDynamic(MicroModule module) async {
    _validator.validate(module);

    for (final dep in module.dependencies) {
      if (!_modules.containsKey(dep)) {
        throw ModuleDependencyNotFoundException(
            'Module "${module.moduleId}" depends on "$dep" '
            'which is not registered.');
      }
    }

    await _registerModule(module);
    await _callOnInit(module);
    _logger.info('✅ Dynamically registered: ${module.moduleName}');
  }

  /// Unregisters a module and cleans up its resources.
  Future<void> unregister(String moduleId) async {
    final module = _modules[moduleId];
    if (module == null) return;

    _logger.info('Unregistering ${module.moduleName}...');
    _lifecycles[moduleId]
        ?.transitionTo(ModuleLifecycleState.disposing);

    try {
      await module.onDispose();
    } catch (e, st) {
      _logger.error('Error disposing ${module.moduleName}: $e',
          error: e, stackTrace: st);
    }

    _injectors[moduleId]?.dispose();
    _modules.remove(moduleId);
    _injectors.remove(moduleId);

    _lifecycles[moduleId]?.transitionTo(ModuleLifecycleState.disposed);
    _emit(ModuleLifecycleEvent(
        moduleId: moduleId, state: ModuleLifecycleState.disposed));
    _lifecycles.remove(moduleId);

    _logger.info('✓ Unregistered $moduleId');
  }

  // ─── App Lifecycle Forwarding ──────────────────────────────────────────────

  Future<void> pauseAll() async {
    for (final module in _modules.values) {
      if (_lifecycles[module.moduleId]?.isReady ?? false) {
        try {
          await module.onPause();
          _lifecycles[module.moduleId]
              ?.transitionTo(ModuleLifecycleState.paused);
        } catch (e, st) {
          _logger.error('Error pausing ${module.moduleName}',
              error: e, stackTrace: st);
        }
      }
    }
  }

  Future<void> resumeAll() async {
    for (final module in _modules.values) {
      if (_lifecycles[module.moduleId]?.isPaused ?? false) {
        try {
          await module.onResume();
          _lifecycles[module.moduleId]?.transitionTo(ModuleLifecycleState.ready);
        } catch (e, st) {
          _logger.error('Error resuming ${module.moduleName}',
              error: e, stackTrace: st);
        }
      }
    }
  }

  Future<void> dispose() async {
    _logger.info('Disposing registry...');
    // Dispose in reverse registration order
    final ids = _modules.keys.toList().reversed.toList();
    for (final id in ids) {
      await unregister(id);
    }
    await _lifecycleController.close();
    // Recreate so the singleton stays usable after dispose() (e.g. in tests).
    _lifecycleController =
        StreamController<ModuleLifecycleEvent>.broadcast(sync: true);
    _initialized = false;
    _logger.info('Registry disposed.');
  }

  // ─── Accessors ─────────────────────────────────────────────────────────────

  /// Retrieve a module by ID with type-safe casting.
  T? getModule<T extends MicroModule>(String moduleId) {
    final m = _modules[moduleId];
    if (m == null) return null;
    if (m is! T) {
      throw ModuleTypeMismatchException(
          'Module "$moduleId" is ${m.runtimeType}, expected $T');
    }
    return m;
  }

  /// Check if a module is registered.
  bool isRegistered(String moduleId) => _modules.containsKey(moduleId);

  /// Check if a module is in [ModuleLifecycleState.ready] state.
  bool isReady(String moduleId) =>
      _lifecycles[moduleId]?.isReady ?? false;

  /// Returns all routes from all [RoutableModule]s.
  List<RouteBase> getAllRoutes() {
    final routes = <RouteBase>[];
    for (final m in _modules.values) {
      if (m is RoutableModule) {
        routes.addAll(m.routes);
      }
    }
    return routes;
  }

  /// Returns root destination modules in navigation order.
  List<RootDestination> getRootDestinations() {
    final reg = RouteRegistration();
    return reg.getRootDestinations(_modules.values.toList());
  }

  /// Returns all registered module IDs.
  List<String> get registeredModuleIds => List.unmodifiable(_modules.keys);

  /// Returns lifecycle diagnostics for all modules.
  Map<String, ModuleLifecycleDiagnostics> get allDiagnostics => {
        for (final e in _lifecycles.entries)
          e.key: e.value.diagnostics,
      };

  /// Returns the [ModuleInjector] for a module (if registered).
  ModuleInjector? getInjector(String moduleId) => _injectors[moduleId];

  // ─── Private ───────────────────────────────────────────────────────────────

  void _emit(ModuleLifecycleEvent event) {
    if (!_lifecycleController.isClosed) {
      _lifecycleController.add(event);
    }
  }
}
