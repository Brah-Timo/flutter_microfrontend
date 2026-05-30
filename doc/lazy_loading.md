# Lazy Loading

## Why Lazy Load?

Loading all modules at startup increases:
- **Time-to-interactive** (slower cold start)
- **Peak memory usage** (all code in memory)

`DeferredModule` defers loading until the module is actually needed.

---

## DeferredModule

```dart
final shopModule = DeferredModule(
  moduleId: 'shop',
  moduleName: 'Shop',
  loader: () async {
    // Optionally use Dart's `deferred` imports for true code splitting
    await shop_lib.loadLibrary();
    return shop_lib.ShopModule();
  },
  preloadStrategy: PreloadStrategy.afterAppReady,
  dependencies: ['auth'],
  config: PreloadConfig(
    maxRetries: 3,
    retryDelay: Duration(seconds: 2),
    loadTimeout: Duration(seconds: 30),
  ),
);
```

---

## PreloadStrategy

| Value | When the module loads |
|-------|-----------------------|
| `onDemand` | Only when `load()` is called explicitly (default) |
| `onFirstNavigation` | When routing to one of this module's routes |
| `afterAppReady` | After all eager modules finish initializing |
| `afterDelay` | After a configurable delay |
| `whenIdle` | 3 seconds after `afterAppReady` |
| `onWifiConnection` | When the device is on Wi-Fi |

---

## ModuleLoader

`ModuleLoader` manages all deferred modules and triggers loading policies:

```dart
final loader = ModuleLoader();

// Register deferred modules
loader.register(shopModule);
loader.register(analyticsModule);

// Trigger afterAppReady loads
await loader.onAppReady();

// Navigate to a path — triggers onFirstNavigation
await loader.onNavigateTo('/shop/products');

// Explicit load by ID
final module = await loader.loadById('shop');

// Status
print(loader.statusMap['shop']?.isLoaded);
```

---

## LazyModuleBuilder

Fluent builder API for constructing `DeferredModule`s:

```dart
final shopModule = LazyModuleBuilder('shop')
  .withName('Shop')
  .withLoader(() async => ShopModule())
  .withDependencies(['auth', 'core'])
  .withStrategy(PreloadStrategy.afterAppReady)
  .withRoutePrefixes(['/shop'])
  .build();
```

---

## Diagnostics

```dart
final diag = shopModule.diagnostics;
print('Loaded: ${diag.isLoaded}');
print('Attempts: ${diag.loadAttempts}');
print('Strategy: ${diag.preloadStrategy}');
print('Loaded at: ${diag.loadedAt}');
```

---

## Unloading

```dart
// Free the module's memory (can be reloaded later)
await shopModule.unload();
```
