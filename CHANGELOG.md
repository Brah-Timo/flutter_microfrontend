# Changelog

All notable changes to `flutter_microfrontend` are documented here.
This project follows [Semantic Versioning](https://semver.org/).

---

## [1.0.0] — 2026-05-29

### 🎉 Initial Release

#### Core Architecture
- **ModuleRegistry**: Singleton central registry with full lifecycle management
- **MicroModule**: Abstract base class defining the complete module contract
- **ModuleLifecycleManager**: Per-module state machine with valid transition enforcement
- **DependencyGraph**: Topological sort (Kahn's algorithm) + DFS cycle detection

#### Navigation
- **ModuleRouter**: Assembles GoRouter from all RoutableModule routes automatically
- **RoutableModule mixin**: Route declaration with root-destination support
- **ModuleRouterConfig**: Customizable redirects, observers, error pages

#### Event System
- **ModuleEventBus**: RxDart-powered typed event bus with replay support
- **EventChannel**: Per-type channel with last-value semantics (BehaviorSubject)
- **MultiChannel**: Manage multiple typed channels in one object
- Built-in system events: `ModuleReadyEvent`, `ModuleErrorEvent`, `UserAuthenticatedEvent`, etc.

#### Dependency Injection
- **ModuleInjector**: Scoped GetIt container per module (isolated)
- **GlobalInjector**: App-wide shared services
- **ScopedLocator**: InheritedWidget for DI access in widget trees

#### Lazy Loading
- **DeferredModule**: Concurrent-safe lazy wrapper with retry logic
- **LazyModuleBuilder**: Fluent builder pattern for DeferredModule construction
- **PreloadStrategy**: 6 strategies: onDemand, onFirstNavigation, afterAppReady, afterDelay, whenIdle, onWifiConnection
- **PreloadConfig**: Fine-grained control over retries, timeouts, delays

#### Plugin System
- **MicroPlugin**: Cross-cutting concern base class
- **PluginRegistry**: Two-phase initialization (before/after modules)
- **AnalyticsPlugin**: Abstract contract for analytics integrations
- **CrashReportingPlugin**: Abstract contract for crash reporting
- **FeatureFlagsPlugin**: Abstract contract for feature flag services
- **PerformancePlugin**: Abstract contract for APM integrations
- Built-in no-op implementations: `NoOpAnalyticsPlugin`, `NoOpCrashReportingPlugin`

#### State Management
- **ModuleStateScope**: InheritedWidget scope per module
- **SharedStateBridge**: Reactive cross-module state sharing
- **EventDrivenBridge**: Auto-updating bridge based on event stream

#### Widgets
- **MicrofrontendApp**: Root widget that bootstraps the entire system
- **ModuleBoundary**: Widget tree boundary with optional debug labels
- **LazyModuleWidget**: FutureBuilder wrapper for DeferredModule rendering
- **ModuleErrorBoundary**: Isolates rendering errors per module

#### Utils
- **ModuleLogger**: Structured logging with emoji levels and history buffer
- **ModuleValidator**: Module validation (ID format, reserved names, self-deps)
- **DependencyGraph**: Graph analysis (toDotGraph, getDependents, getAllDependencies)

#### Testing
- **MockModule**: Fully configurable mock with lifecycle call tracking
- **MockEventBus**: Records all emitted events for assertion
- Unit tests: ModuleRegistry, EventBus, DependencyGraph, DeferredModule

#### Example App
- Complete demo with 2 eager + 2 lazy modules
- AuthModule (eager, priority 100) with login screen
- HomeModule (eager, root destination)
- ShopModule (lazy, afterAppReady strategy)
- SettingsModule (lazy, whenIdle strategy)
- ConsoleAnalyticsPlugin example

---

## [0.9.0-beta] — 2026-04-15
- Internal beta release for architecture validation
- Core registry and event bus prototypes
