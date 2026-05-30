# Module System

## MicroModule

`MicroModule` is the base class every feature implements:

```dart
abstract class MicroModule {
  String get moduleId;    // unique, URL-safe ID
  String get moduleName;  // display name
  List<String> get dependencies => const [];
  bool get isEager => false;
  int get loadPriority => 0;

  Future<void> onRegister(ModuleInjector injector) async {}
  Future<void> onInit() async {}
  Future<void> onPause() async {}
  Future<void> onResume() async {}
  Future<void> onDispose() async {}
}
```

---

## ModuleRegistry

The singleton registry orchestrates the entire lifecycle:

```dart
// Bootstrap
await ModuleRegistry.instance.initialize(
  modules: [AuthModule(), HomeModule(), DeferredModule(...)],
  globalInjector: GlobalInjector(),
  eventBus: ModuleEventBus(),
);

// Dynamic registration at runtime
await ModuleRegistry.instance.registerDynamic(NewFeatureModule());

// Query
final isReady = ModuleRegistry.instance.isReady('auth');

// Lifecycle forwarding
await ModuleRegistry.instance.pauseAll();
await ModuleRegistry.instance.resumeAll();

// Cleanup
await ModuleRegistry.instance.dispose();
```

---

## RoutableModule Mixin

Add navigation to any module:

```dart
class HomeModule extends MicroModule with RoutableModule {
  @override String get moduleId => 'home';
  @override String get moduleName => 'Home';

  @override
  List<RouteBase> get routes => [
    GoRoute(path: '/home', builder: (ctx, state) => HomeScreen()),
  ];

  @override bool get isRootDestination => true;
  @override String? get navigationLabel => 'Home';
  @override String? get navigationIconName => 'home';
  @override int get navigationOrder => 0;
}
```

---

## EventAwareModule Mixin

Integrate with the event bus:

```dart
class OrderModule extends MicroModule with EventAwareModule {
  @override String get moduleId => 'orders';
  @override String get moduleName => 'Orders';

  @override
  Future<void> onInit() async {
    // listen() auto-cancels the subscription on dispose
    listen<PaymentSucceededEvent>((event) {
      _createOrder(event.orderId);
    });
    await super.onInit();
  }
}
```

---

## ServiceModule Mixin

Register services globally before other modules initialize:

```dart
class CoreModule extends MicroModule with ServiceModule {
  @override String get moduleId => 'core';
  @override String get moduleName => 'Core';
  @override bool get registerGlobalServicesFirst => true;

  @override
  Future<void> registerGlobalServices(ModuleInjector injector) async {
    injector.global.registerSingleton<HttpClient>(
      DioHttpClient(baseUrl: AppConfig.apiBase),
    );
  }
}
```

---

## Lifecycle State Machine

```
registered
    │
    ▼
initializing ──error──► error
    │
    ▼
  ready ◄──resume──── paused
    │                    ▲
    └───────pause────────┘
    │
    ▼
 disposing
    │
    ▼
 disposed
```
