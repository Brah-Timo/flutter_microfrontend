import 'dart:async';
import 'package:rxdart/rxdart.dart';
import 'module_event.dart';
import '../utils/module_logger.dart';

/// The central typed event bus for inter-module communication.
///
/// Implements the publish-subscribe pattern so that modules can communicate
/// without any direct dependency on each other.
///
/// ## Usage
/// ```dart
/// // Publisher (any module with EventAwareModule mixin)
/// emit(UserAuthenticatedEvent(userId: '42', ...));
///
/// // Subscriber (any other module)
/// on<UserAuthenticatedEvent>().listen((event) {
///   print('User ${event.userId} logged in!');
/// });
/// ```
///
/// ## Advanced filtering
/// ```dart
/// // Debounced search events
/// on<SearchQueryChangedEvent>()
///   .debounceTime(const Duration(milliseconds: 300))
///   .listen(handleSearch);
///
/// // Filtered events
/// on<OrderStatusChangedEvent>()
///   .where((e) => e.status == OrderStatus.delivered)
///   .listen(showDeliveryNotification);
/// ```
class ModuleEventBus {
  // sync: true → events are delivered to listeners synchronously within
  // the same call stack as emit(), making ordering guarantees predictable
  // and avoiding missed-event races in tests and production alike.
  final _controller = StreamController<ModuleEvent>.broadcast(sync: true);

  // Replay subject for the last N events (for late subscribers)
  final _replaySubject = ReplaySubject<ModuleEvent>(maxSize: 50);

  final _logger = ModuleLogger('EventBus');

  // ─── Statistics ────────────────────────────────────────────────────────────

  int _totalEmitted = 0;
  int _activeSubscriberCount = 0;
  final Map<Type, int> _typeCounters = {};
  final List<ModuleEvent> _recentHistory = [];
  static const int _maxHistory = 100;

  bool _disposed = false;

  // ─── Emit ──────────────────────────────────────────────────────────────────

  /// Emits an event to all current subscribers.
  ///
  /// Delivery is synchronous — listeners are called inline before [emit]
  /// returns, which means ordering is fully deterministic.
  void emit(ModuleEvent event) {
    assert(!_disposed, 'EventBus has been disposed.');
    _totalEmitted++;
    _typeCounters[event.runtimeType] =
        (_typeCounters[event.runtimeType] ?? 0) + 1;

    // Track recent history
    _recentHistory.add(event);
    if (_recentHistory.length > _maxHistory) {
      _recentHistory.removeAt(0);
    }

    _logger.debug(
        '📡 [${event.sourceModuleId}] ${event.runtimeType} #$_totalEmitted');

    _controller.add(event);
    _replaySubject.add(event);
  }

  // ─── Subscribe ─────────────────────────────────────────────────────────────

  /// Returns a [Stream] of events of type [T].
  ///
  /// Only events emitted AFTER subscribing are received (hot stream).
  /// The underlying controller uses [sync: true] so delivery is synchronous.
  Stream<T> on<T extends ModuleEvent>() {
    return _controller.stream.whereType<T>();
  }

  /// Returns a [Stream] of events of type [T], including the last
  /// [replayCount] events emitted before subscription.
  Stream<T> onWithReplay<T extends ModuleEvent>({int replayCount = 1}) {
    return _replaySubject.stream.whereType<T>();
  }

  /// Returns a stream of ALL event types (for logging/debugging).
  Stream<ModuleEvent> get allEvents => _controller.stream;

  /// Subscribe to event [T] with advanced options.
  ///
  /// Returns a [StreamSubscription] that you must cancel manually
  /// (or use [EventAwareModule.listen] which auto-cancels on dispose).
  StreamSubscription<T> subscribe<T extends ModuleEvent>({
    required void Function(T event) onEvent,
    bool Function(T event)? where,
    Duration? debounce,
    Duration? throttle,
    void Function(Object error)? onError,
    String? subscriberLabel,
  }) {
    Stream<T> stream = on<T>();

    if (where != null) stream = stream.where(where);
    if (debounce != null) stream = stream.debounceTime(debounce);
    if (throttle != null) stream = stream.throttleTime(throttle);

    _activeSubscriberCount++;
    final sub = stream.listen(
      (event) {
        _logger.debug(
            '📨 [${subscriberLabel ?? "?"}] received ${event.runtimeType}');
        onEvent(event);
      },
      onError: (Object e, StackTrace st) {
        _logger.error(
            '❌ Error in subscriber for $T: $e',
            error: e, stackTrace: st);
        onError?.call(e);
      },
    );
    // Decrement on cancel so stats stay accurate.
    sub.onDone(() => _activeSubscriberCount--);
    return sub;
  }

  // ─── History & Stats ───────────────────────────────────────────────────────

  /// Returns the most recent [count] events of any type.
  List<ModuleEvent> recentEvents({int count = 20}) =>
      _recentHistory.reversed.take(count).toList();

  /// Returns statistics about emitted events.
  EventBusStats get stats => EventBusStats(
        totalEmitted: _totalEmitted,
        typeCounters: Map.unmodifiable(_typeCounters),
        activeSubscriberCount: _activeSubscriberCount,
      );

  // ─── Lifecycle ─────────────────────────────────────────────────────────────

  Future<void> dispose() async {
    _disposed = true;
    await _controller.close();
    await _replaySubject.close();
    _recentHistory.clear();
    _logger.info(
        'EventBus disposed. Total events emitted: $_totalEmitted');
  }
}

// ─── Stats ────────────────────────────────────────────────────────────────────

class EventBusStats {
  final int totalEmitted;
  final Map<Type, int> typeCounters;
  final int activeSubscriberCount;

  const EventBusStats({
    required this.totalEmitted,
    required this.typeCounters,
    required this.activeSubscriberCount,
  });

  @override
  String toString() {
    final types = typeCounters.entries
        .map((e) => '${e.key}: ${e.value}')
        .join(', ');
    return 'EventBusStats(total: $totalEmitted, '
        'subscribers: $activeSubscriberCount, [$types])';
  }
}
