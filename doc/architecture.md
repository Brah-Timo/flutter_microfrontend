# Architecture Overview

## Design Philosophy

`flutter_microfrontend` applies **micro-frontend principles** to Flutter:

- Each feature lives in an isolated `MicroModule`
- Modules communicate **only** through the `ModuleEventBus` (no direct imports)
- Dependency injection is scoped per module (`ModuleInjector`)
- Navigation routes are declared per-module and assembled centrally
- Plugins handle cross-cutting concerns (analytics, crash reporting, flags)

---

## Layer Diagram

```
┌──────────────────────────────────────────────────────────────┐
│                      MicrofrontendApp                        │
│   (entry point — wires registry, bus, plugins, router)       │
└────────────┬────────────────────────────────────┬────────────┘
             │                                    │
   ┌─────────▼─────────┐              ┌───────────▼──────────┐
   │   ModuleRegistry  │              │    PluginRegistry    │
   │  (lifecycle mgmt) │              │  (cross-cutting)     │
   └──────┬────────────┘              └──────────────────────┘
          │ registers/inits
   ┌──────▼──────────────────────────────────────────────┐
   │                   MicroModule(s)                    │
   │  ┌─────────────┐  ┌───────────┐  ┌──────────────┐  │
   │  │  AuthModule │  │ HomeModule│  │  ShopModule  │  │
   │  │             │  │           │  │ (deferred)   │  │
   │  └──────┬──────┘  └─────┬─────┘  └──────┬───────┘  │
   │         │               │               │           │
   │         └───────────────▼───────────────┘           │
   │                  ModuleEventBus                      │
   └─────────────────────────────────────────────────────┘
          │
   ┌──────▼────────────┐
   │   ModuleRouter    │
   │  (GoRouter built  │
   │  from all routes) │
   └───────────────────┘
```

---

## Dependency Injection

Each module has a **scoped** `ModuleInjector` that can:
- Register module-private singletons and factories
- Access the global `GlobalInjector` for app-wide singletons

```dart
@override
Future<void> onRegister(ModuleInjector injector) async {
  // Module-scoped singleton
  injector.registerLazySingleton<CartService>(() => CartServiceImpl());

  // Access a global service
  final analytics = injector.global.get<AnalyticsService>();
  await super.onRegister(injector);
}
```

---

## Navigation

Modules that implement `RoutableModule` contribute routes to the central
`ModuleRouter`, which assembles a `GoRouter`.

```dart
class ShopModule extends MicroModule with RoutableModule {
  @override
  List<RouteBase> get routes => [
    GoRoute(path: '/shop', builder: (ctx, state) => ShopScreen()),
    GoRoute(path: '/shop/:id', builder: (ctx, state) => ProductScreen()),
  ];
}
```

---

## Dependency Resolution Order

The `DependencyGraph` performs a **topological sort** before initialization,
ensuring every module is ready before any module that depends on it.

```
AuthModule (no deps) → CoreModule (depends on auth) → HomeModule (depends on core)
```

Circular dependencies are detected at startup and throw a
`CircularDependencyException`.
