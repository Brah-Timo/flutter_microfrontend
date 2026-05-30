# Getting Started with flutter_microfrontend

`flutter_microfrontend` is a Flutter package that lets you structure large apps
as a set of independent, isolated **feature modules** — each with its own DI
container, navigation routes, event subscriptions, and lifecycle.

---

## Installation

```yaml
# pubspec.yaml
dependencies:
  flutter_microfrontend: ^1.0.0
```

---

## Minimal Example

```dart
import 'package:flutter/material.dart';
import 'package:flutter_microfrontend/flutter_microfrontend.dart';

// 1. Define a module
class AuthModule extends MicroModule {
  @override String get moduleId => 'auth';
  @override String get moduleName => 'Authentication';

  @override
  Future<void> onRegister(ModuleInjector injector) async {
    injector.registerLazySingleton<AuthService>(() => AuthServiceImpl());
    await super.onRegister(injector);
  }
}

// 2. Bootstrap
void main() {
  runApp(
    MicrofrontendApp(
      modules: [AuthModule(), HomeModule()],
      plugins: [NoOpAnalyticsPlugin()],
    ),
  );
}
```

---

## Module Lifecycle

```
register → init → ready → [pause ↔ resume]* → dispose
```

| Callback | Purpose |
|----------|---------|
| `onRegister(injector)` | Register services into the module's DI scope |
| `onInit()` | Cross-module wiring (subscribe to events, read other modules) |
| `onPause()` | App goes to background |
| `onResume()` | App returns to foreground |
| `onDispose()` | Release resources, cancel subscriptions |

---

## Core Classes

| Class | Description |
|-------|-------------|
| `MicroModule` | Base class every feature implements |
| `ModuleRegistry` | Singleton — owns all modules, controls lifecycle |
| `ModuleEventBus` | Typed publish-subscribe bus for inter-module events |
| `ModuleInjector` | Scoped DI container (backed by `get_it`) |
| `DeferredModule` | Lazy-loading wrapper for any `MicroModule` |
| `MicroPlugin` | Cross-cutting concern (analytics, crash reporting, …) |

---

## Next Steps

- [Architecture Overview](architecture.md)
- [Module System](module_system.md)
- [Event Bus](event_bus.md)
- [Lazy Loading](lazy_loading.md)
- [Plugin System](plugin_system.md)
