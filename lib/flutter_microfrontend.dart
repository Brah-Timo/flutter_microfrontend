/// flutter_microfrontend
///
/// A comprehensive package for building Flutter applications using
/// micro-frontend architecture principles.
///
/// ## Core Concepts
/// - **MicroModule**: The fundamental unit — each feature is an isolated module
/// - **ModuleRegistry**: Central registry managing all module lifecycles
/// - **ModuleEventBus**: Typed, reactive inter-module communication
/// - **ModuleInjector**: Scoped dependency injection per module
/// - **DeferredModule**: Lazy-loaded module wrapper
/// - **MicroPlugin**: Cross-cutting concerns (analytics, crash reporting, etc.)
///
/// ## Quick Start
/// ```dart
/// void main() {
///   runApp(
///     MicrofrontendApp(
///       modules: [
///         AuthModule(),
///         HomeModule(),
///         DeferredModule(
///           moduleId: 'shop',
///           loader: () async => ShopModule(),
///         ),
///       ],
///       plugins: [AnalyticsPlugin()],
///     ),
///   );
/// }
/// ```
library flutter_microfrontend;

// ─── Contracts ───────────────────────────────────────────────────────────────
export 'src/contracts/event_aware_module.dart';
export 'src/contracts/module_contract.dart';
export 'src/contracts/routable_module.dart';
export 'src/contracts/service_module.dart';

// ─── Core ────────────────────────────────────────────────────────────────────
export 'src/core/microfrontend_app.dart';
export 'src/core/module_lifecycle.dart';
export 'src/core/module_loader.dart';
export 'src/core/module_registry.dart';

// ─── Events ──────────────────────────────────────────────────────────────────
export 'src/events/event_bus.dart';
export 'src/events/event_channel.dart';
export 'src/events/module_event.dart';

// ─── Injection ───────────────────────────────────────────────────────────────
export 'src/injection/global_injector.dart';
export 'src/injection/module_injector.dart';
export 'src/injection/scoped_locator.dart';

// ─── Lazy Loading ────────────────────────────────────────────────────────────
export 'src/lazy/deferred_module.dart';
export 'src/lazy/lazy_module_builder.dart';
export 'src/lazy/preload_strategy.dart';

// ─── Navigation ──────────────────────────────────────────────────────────────
export 'src/navigation/module_router.dart';
export 'src/navigation/navigation_contract.dart';
export 'src/navigation/route_registration.dart';

// ─── Plugins ─────────────────────────────────────────────────────────────────
export 'src/plugins/plugin_contract.dart';
export 'src/plugins/plugin_initializer.dart';
export 'src/plugins/plugin_registry.dart';

// ─── State ───────────────────────────────────────────────────────────────────
export 'src/state/module_state_scope.dart';
export 'src/state/shared_state_bridge.dart';

// ─── Utils ───────────────────────────────────────────────────────────────────
export 'src/utils/dependency_graph.dart';
export 'src/utils/module_logger.dart';
export 'src/utils/module_validator.dart';

// ─── Widgets ─────────────────────────────────────────────────────────────────
export 'src/widgets/lazy_module_widget.dart';
export 'src/widgets/module_boundary.dart';
export 'src/widgets/module_error_boundary.dart';
