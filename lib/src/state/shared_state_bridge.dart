import 'dart:async';
import 'package:flutter/foundation.dart';
import '../events/event_bus.dart';
import '../events/module_event.dart';

/// A reactive bridge for sharing specific state between modules.
///
/// Unlike direct service sharing via [GlobalInjector], [SharedStateBridge]
/// uses a stream-based approach that keeps modules decoupled while allowing
/// them to react to each other's state changes.
///
/// ## Example: Sharing cart item count between shop and header modules
/// ```dart
/// // Create the bridge (in GlobalInjector shared services)
/// injector.registerSingleton<CartStateBridge>(CartStateBridge());
///
/// // In ShopModule — update the bridge
/// final bridge = injector.get<CartStateBridge>();
/// bridge.update(cartItemCount);
///
/// // In HeaderModule — react to changes
/// final bridge = injector.get<CartStateBridge>();
/// bridge.stream.listen((count) => updateBadge(count));
/// ```
class SharedStateBridge<T> {
  final String bridgeId;
  final T _initialValue;
  late final ValueNotifier<T> _notifier;
  final _controller = StreamController<T>.broadcast();
  bool _disposed = false;

  SharedStateBridge({
    required this.bridgeId,
    required T initialValue,
  }) : _initialValue = initialValue {
    _notifier = ValueNotifier<T>(initialValue);
    _notifier.addListener(_onNotifierChange);
  }

  void _onNotifierChange() {
    if (!_disposed) {
      _controller.add(_notifier.value);
    }
  }

  // ─── Read ──────────────────────────────────────────────────────────────────

  T get value => _notifier.value;
  Stream<T> get stream => _controller.stream;
  ValueListenable<T> get listenable => _notifier;

  // ─── Write ─────────────────────────────────────────────────────────────────

  void update(T newValue) {
    assert(!_disposed, 'SharedStateBridge $bridgeId is disposed.');
    if (_notifier.value != newValue) {
      _notifier.value = newValue;
    }
  }

  void reset() => update(_initialValue);

  // ─── Dispose ───────────────────────────────────────────────────────────────

  Future<void> dispose() async {
    if (!_disposed) {
      _disposed = true;
      _notifier.removeListener(_onNotifierChange);
      _notifier.dispose();
      await _controller.close();
    }
  }
}

// ─── Event-Driven Bridge ──────────────────────────────────────────────────────

/// A [SharedStateBridge] that automatically updates based on [ModuleEvent]s.
///
/// ```dart
/// // Automatically track auth state from UserAuthenticatedEvent
/// final authBridge = EventDrivenBridge<bool, UserAuthenticatedEvent>(
///   bridgeId: 'is_authenticated',
///   initialValue: false,
///   eventBus: eventBus,
///   reducer: (event) => true,
/// );
/// // Now any widget can check authBridge.value
/// ```
class EventDrivenBridge<T, E extends ModuleEvent>
    extends SharedStateBridge<T> {
  late final StreamSubscription<E> _sub;

  EventDrivenBridge({
    required super.bridgeId,
    required super.initialValue,
    required ModuleEventBus eventBus,
    required T Function(E event) reducer,
    bool Function(E event)? filter,
  }) {
    var stream = eventBus.on<E>();
    if (filter != null) stream = stream.where(filter);
    _sub = stream.listen((event) => update(reducer(event)));
  }

  @override
  Future<void> dispose() async {
    await _sub.cancel();
    await super.dispose();
  }
}
