import 'dart:async';
import 'package:rxdart/rxdart.dart';
import 'event_bus.dart';
import 'module_event.dart';

/// A typed, strongly-scoped channel for a specific event type [T].
///
/// Use when you need persistent state (last value), custom operators,
/// or a dedicated channel for frequent/high-volume events.
///
/// ```dart
/// // Create a channel for cart update events
/// final cartChannel = EventChannel<CartUpdatedEvent>(eventBus);
///
/// // Subscribe with operators
/// cartChannel.stream
///   .where((e) => e.itemCount > 0)
///   .debounceTime(const Duration(milliseconds: 200))
///   .listen(updateCartBadge);
///
/// // Emit through the channel
/// cartChannel.emit(CartUpdatedEvent(itemCount: 3, ...));
///
/// // Get last emitted value
/// final last = cartChannel.lastEvent;
/// ```
class EventChannel<T extends ModuleEvent> {
  final ModuleEventBus _bus;
  final BehaviorSubject<T> _subject = BehaviorSubject<T>();
  late final StreamSubscription<T> _busSubscription;

  EventChannel(this._bus) {
    // Mirror events of type T from the global bus
    _busSubscription = _bus.on<T>().listen(_subject.add);
  }

  // ─── Emit ──────────────────────────────────────────────────────────────────

  /// Emits an event through this channel AND the global event bus.
  void emit(T event) {
    _bus.emit(event);
    // _subject will receive it via the bus subscription above
  }

  // ─── Subscribe ─────────────────────────────────────────────────────────────

  /// Stream of events on this channel.
  Stream<T> get stream => _subject.stream;

  /// Last event received on this channel (null if none yet).
  T? get lastEvent => _subject.valueOrNull;

  /// Whether the channel has received at least one event.
  bool get hasValue => _subject.hasValue;

  // ─── Convenience Operators ─────────────────────────────────────────────────

  /// Debounced stream of events.
  Stream<T> debounced(Duration duration) =>
      stream.debounceTime(duration);

  /// Throttled stream of events.
  Stream<T> throttled(Duration duration) =>
      stream.throttleTime(duration);

  /// Stream of events matching a filter.
  Stream<T> where(bool Function(T event) test) =>
      stream.where(test);

  /// Map events to another type.
  Stream<R> map<R>(R Function(T event) transform) =>
      stream.map(transform);

  // ─── Lifecycle ─────────────────────────────────────────────────────────────

  Future<void> dispose() async {
    await _busSubscription.cancel();
    await _subject.close();
  }
}

// ─── MultiChannel ────────────────────────────────────────────────────────────

/// Manages multiple [EventChannel]s of different types.
///
/// Useful when a module subscribes to several event types and wants
/// last-value semantics for each.
///
/// ```dart
/// class HomeModule extends MicroModule with EventAwareModule {
///   late final MultiChannel _channels;
///
///   @override
///   Future<void> onInit() async {
///     _channels = MultiChannel(_eventBus);
///     _channels.channel<UserAuthenticatedEvent>().stream.listen(...);
///     _channels.channel<ThemeChangedEvent>().stream.listen(...);
///   }
///
///   @override
///   Future<void> onDispose() async {
///     await _channels.disposeAll();
///   }
/// }
/// ```
class MultiChannel {
  final ModuleEventBus _bus;
  final Map<Type, EventChannel<dynamic>> _channels = {};

  MultiChannel(this._bus);

  /// Returns (or creates) a typed channel for event type [T].
  EventChannel<T> channel<T extends ModuleEvent>() {
    return _channels.putIfAbsent(T, () => EventChannel<T>(_bus))
        as EventChannel<T>;
  }

  /// Disposes all channels.
  Future<void> disposeAll() async {
    for (final ch in _channels.values) {
      await ch.dispose();
    }
    _channels.clear();
  }
}
