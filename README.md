
[![pub version](https://img.shields.io/badge/pub-v1.0.0-blue)](https://pub.dev/packages/flutter_microfrontend)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Dart SDK](https://img.shields.io/badge/Dart-%3E%3D3.0.0-0175C2)](https://dart.dev)
[![Flutter](https://img.shields.io/badge/Flutter-%3E%3D3.10.0-02569B)](https://flutter.dev)

> **Build large-scale Flutter apps as independent, lazy-loadable feature modules.**

<img width="1376" height="768" alt="image" src="https://github.com/user-attachments/assets/873f1b71-080a-4432-95c6-ff2de1ef93b8" />



`flutter_microfrontend` brings **micro-frontend architecture** principles to Flutter — enabling teams to split apps into fully isolated feature units that can be loaded, unloaded, and developed independently.

---

## ✨ Feature Highlights

| Feature | Description |
|---------|-------------|
| 🔒 **True Module Isolation** | Each module has its own DI container, state scope, and event subscriptions |
| ⚡ **Lazy Loading** | 6 preload strategies — load modules only when needed |
| 📡 **Typed Event Bus** | RxDart-powered pub/sub with type safety, debounce, throttle |
| 🔌 **Plugin Architecture** | Analytics, Crash Reporting, Feature Flags — all decoupled |
| 🗺️ **Modular Routing** | Auto-collects routes from all modules via GoRouter |
| 🧪 **Highly Testable** | Every module is independently testable with mock helpers |
| 🔁 **Dynamic Registration** | Register/unregister modules at runtime |
| 🛡️ **Error Isolation** | `ModuleErrorBoundary` prevents cascade failures |
| 📊 **Lifecycle Events** | Observable stream of every module state change |
| 🔍 **Dep Graph Analysis** | Visualize dependencies, detect cycles at startup |

---

## 📦 Installation

```yaml
dependencies:
  flutter_microfrontend: ^1.0.0
```

```bash
flutter pub get
```

---

## 🚀 Quick Start

### 1. Create a Module

```dart
import 'package:flutter_microfrontend/flutter_microfrontend.dart';
import 'package:go_router/go_router.dart';

class AuthModule extends MicroModule with RoutableModule, EventAwareModule {
  @override String get moduleId => 'auth';
  @override String get moduleName => 'Authentication';
  @override bool get isEager => true;
  @override int get loadPriority => 100;
  @override List<Type> get publishedEvents => [UserSignedInEvent];

  @override
  Future<void> onRegister(ModuleInjector injector) async {
    injector.registerLazySingleton<AuthService>(() => FirebaseAuthService());
  }

  @override
  List<RouteBase> get routes => [
    GoRoute(
      path: '/login',
      builder: (ctx, state) => LoginScreen(
        onSuccess: (userId) => emit(UserSignedInEvent(
          userId: userId, sourceModuleId: moduleId,
        )),
      ),
    ),
  ];
}
```

### 2. Bootstrap the App

```dart
void main() {
  runApp(
    MicrofrontendApp(
      title: 'My App',
      modules: [
        // Eager — critical modules loaded at startup
        AuthModule(),
        HomeModule(),

        // Lazy — loaded on demand
        DeferredModule(
          moduleId: 'shop',
          loader: () async => ShopModule(),
          preloadStrategy: PreloadStrategy.afterAppReady,
          dependencies: ['auth'],
        ),
        DeferredModule(
          moduleId: 'settings',
          loader: () async => SettingsModule(),
          preloadStrategy: PreloadStrategy.whenIdle,
        ),
      ],
      plugins: [
        FirebaseAnalyticsPlugin(),
        SentryPlugin(dsn: 'https://...'),
      ],
      sharedServices: (injector) {
        injector.registerSingleton<HttpClient>(DioClient());
        injector.registerSingleton<LocalStorage>(HiveStorage());
      },
    ),
  );
}
```

---

## 🧩 Module Contracts (Mixins)

| Mixin | Purpose |
|-------|---------|
| `RoutableModule` | Declare GoRouter routes |
| `EventAwareModule` | Publish and subscribe to typed events |
| `ServiceModule` | Expose services to the global DI container |

```dart
class ShopModule extends MicroModule
    with RoutableModule, EventAwareModule, ServiceModule {
  @override String get moduleId => 'shop';
  // ... implements all three contracts
}
```

---

## 📡 Event System

```dart
// Publisher (in ShopModule)
emit(OrderPlacedEvent(orderId: 'ORD-123', sourceModuleId: moduleId));

// Subscriber (in any other module, no coupling)
on<OrderPlacedEvent>().listen((event) {
  showNotification('Order ${event.orderId} placed!');
});

// Auto-cancelled listener (tied to module lifecycle)
listen<UserSignedOutEvent>((event) => clearCart());

// Advanced: filter + debounce
eventBus.subscribe<SearchQueryEvent>(
  onEvent: runSearch,
  where: (e) => e.query.length > 2,
  debounce: const Duration(milliseconds: 300),
);
```

---

## ⚡ Lazy Loading

```dart
// Builder pattern
final analyticsModule = LazyModuleBuilder('analytics')
  .withName('Analytics Dashboard')
  .withLoader(() async => AnalyticsDashboardModule())
  .withDependencies(['auth'])
  .withStrategy(PreloadStrategy.whenIdle)
  .withConfig(PreloadConfig(maxRetries: 3))
  .build();

// In UI: show loading state automatically
LazyModuleWidget(
  module: shopDeferredModule,
  builder: (ctx, module) => ShopHomePage(),
  loading: const ShopSkeletonScreen(),
  error: (err, retry) => ShopErrorPage(onRetry: retry),
)
```

### Preload Strategies

| Strategy | When |
|----------|------|
| `onDemand` | Only when explicitly called |
| `onFirstNavigation` | When user navigates to the module |
| `afterAppReady` | Shortly after all eager modules initialize |
| `afterDelay` | After a configurable delay |
| `whenIdle` | When the device is idle (3s after startup) |
| `onWifiConnection` | When Wi-Fi is available |

---

## 🔌 Plugin System

```dart
class FirebaseAnalyticsPlugin extends AnalyticsPlugin {
  @override String get pluginId => 'firebase_analytics';
  @override bool get initializeBeforeModules => true;

  @override
  Future<void> initialize(GlobalInjector injector, ModuleEventBus bus) async {
    await Firebase.initializeApp();
    injector.registerSingleton<FirebaseAnalytics>(FirebaseAnalytics.instance);
  }

  @override
  Future<void> trackScreen(String name, {String? moduleId, ...}) async {
    await FirebaseAnalytics.instance.setCurrentScreen(screenName: name);
  }
}
```

---

## 💉 Dependency Injection

```dart
// In onRegister — module-local services
injector.registerLazySingleton<CartRepository>(
  () => CartRepositoryImpl(http: injector.get<HttpClient>()),
);

// Expose a service globally (other modules can use it)
injector.exposeGlobally<AuthService>(() => FirebaseAuthService());

// In widgets — access from widget tree
final cartService = ScopedLocator.of(context).get<CartRepository>();
// or with extension:
final cartService = context.read<CartRepository>();
```

---

## 🧪 Testing

```dart
// Use MockModule for isolated tests
final mockAuth = MockModule(
  id: 'auth',
  moduleName: 'Auth',
  onInitCallback: () => print('Auth init!'),
);

// Use MockEventBus to verify events
final bus = MockEventBus();
bus.emit(UserSignedInEvent(userId: '1', ...));
expect(bus.eventsOfType<UserSignedInEvent>().length, equals(1));
```

---

## 🏗️ Architecture Overview

```
┌───────────────────────────────────────────────────────┐
│                   MicrofrontendApp                    │
│  (Bootstrap: registry + event bus + plugins + router) │
└─────┬──────────────────────┬────────────────────┬─────┘
      │                      │                    │
 PluginRegistry        ModuleRegistry       ModuleRouter
  (Analytics,          (Lifecycle +          (All Routes
   Sentry, Flags)       DI + Events)          from all
                                              Modules)
      │
      ├── GlobalInjector (shared services)
      │
      ├── AuthModule ──── ModuleInjector (scoped)
      │                   EventAwareModule (publishes/subscribes)
      │
      ├── HomeModule ──── ModuleInjector (scoped)
      │                   Subscribes to AuthModule events
      │
      └── DeferredModule (ShopModule) ── Not loaded until needed
          DeferredModule (SettingsModule) ── Loads when idle
```

---

## 📁 Package Structure

```
lib/
├── flutter_microfrontend.dart  ← Single barrel export
└── src/
    ├── core/                   ← Registry, Loader, Lifecycle, App
    ├── contracts/              ← MicroModule + all mixins
    ├── navigation/             ← ModuleRouter, RouteRegistration
    ├── events/                 ← EventBus, ModuleEvent, EventChannel
    ├── injection/              ← ModuleInjector, GlobalInjector, ScopedLocator
    ├── lazy/                   ← DeferredModule, LazyModuleBuilder, PreloadStrategy
    ├── plugins/                ← MicroPlugin, PluginRegistry, specialized contracts
    ├── state/                  ← ModuleStateScope, SharedStateBridge
    ├── widgets/                ← ModuleBoundary, LazyModuleWidget, ErrorBoundary
    └── utils/                  ← Logger, Validator, DependencyGraph
```

---

## 📐 Design Principles

1. **Isolation First** — Modules cannot directly import each other
2. **Lazy by Default** — Load only what's needed, when it's needed
3. **Explicit Contracts** — Every module declares what it provides and needs
4. **Pluggable** — Add/remove plugins without touching modules
5. **Observable** — Every lifecycle transition is emitted to a stream

---

## 🔗 Dependencies

| Package | Purpose |
|---------|---------|
| `rxdart` | Reactive Event Bus (PublishSubject, BehaviorSubject, operators) |
| `get_it` | Scoped DI containers |
| `go_router` | Modular routing |
| `equatable` | Value equality for events |
| `logging` | Structured logging |
| `meta` | Annotations (`@mustCallSuper`, etc.) |

---

## 📄 License

MIT — see [LICENSE](LICENSE)
