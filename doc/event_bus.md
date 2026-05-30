# Event Bus

## Overview

`ModuleEventBus` is the typed, reactive pub-sub backbone for inter-module
communication. Modules never import each other — they communicate through events.

---

## Defining Events

```dart
// Any class extending ModuleEvent is an event
class UserAuthenticatedEvent extends ModuleEvent {
  final String userId;
  final String role;

  const UserAuthenticatedEvent({
    required this.userId,
    required this.role,
    required super.sourceModuleId,
  });
}
```

---

## Publishing Events

```dart
class AuthModule extends MicroModule with EventAwareModule {
  Future<void> _signIn(String email, String password) async {
    final user = await _authService.signIn(email, password);
    emit(UserAuthenticatedEvent(
      userId: user.id,
      role: user.role,
      sourceModuleId: moduleId,
    ));
  }
}
```

---

## Subscribing to Events

### Via `EventAwareModule.listen` (auto-cancels on module dispose)

```dart
class HomeModule extends MicroModule with EventAwareModule {
  @override
  Future<void> onInit() async {
    listen<UserAuthenticatedEvent>((event) {
      _loadUserDashboard(event.userId);
    });
    await super.onInit();
  }
}
```

### Via `ModuleEventBus.on<T>()` (manual subscription management)

```dart
final subscription = eventBus.on<UserAuthenticatedEvent>().listen((event) {
  print('User ${event.userId} signed in');
});

// Cancel when done
await subscription.cancel();
```

### With advanced options

```dart
eventBus.subscribe<SearchQueryChangedEvent>(
  onEvent: (event) => _search(event.query),
  where: (event) => event.query.length >= 3,
  debounce: const Duration(milliseconds: 300),
  subscriberLabel: 'HomeModule.search',
);
```

---

## Replay Subject

Late subscribers can receive the last N events:

```dart
// Receive last 1 event of this type (default replayCount)
eventBus.onWithReplay<UserAuthenticatedEvent>().listen((event) {
  // Called immediately with the last event if one was emitted
});
```

---

## Statistics

```dart
final stats = eventBus.stats;
print('Total events emitted: ${stats.totalEmitted}');
print('Active subscribers: ${stats.activeSubscriberCount}');

// Recent event history
final recent = eventBus.recentEvents(count: 10);
```
