import 'dart:async';
import 'module_contract.dart';
import '../events/event_bus.dart';
import '../events/module_event.dart';

/// Mixin for modules that participate in the inter-module event system.
///
/// Modules with this mixin can publish and subscribe to typed events
/// without any direct coupling to other modules.
///
/// ## Example
/// ```dart
/// class AuthModule extends MicroModule with EventAwareModule {
///   @override String get moduleId => 'auth';
///   @override String get moduleName => 'Auth';
///
///   // Declare which events this module publishes
///   @override
///   List<Type> get publishedEvents => [
///     UserAuthenticatedEvent,
///     UserSignedOutEvent,
///   ];
///
///   // Sign-in flow
///   Future<void> signIn(String email, String password) async {
///     // ... auth logic ...
///     emit(UserAuthenticatedEvent(userId: user.id, sourceModuleId: moduleId));
///   }
/// }
///
/// // Another module listens without knowing about AuthModule directly:
/// class HomeModule extends MicroModule with EventAwareModule {
///   @override
///   Future<void> onInit() async {
///     on<UserAuthenticatedEvent>().listen((event) {
///       // Update home state
///     });
///   }
/// }
/// ```
mixin EventAwareModule on MicroModule {
  // ─── API Declaration ───────────────────────────────────────────────────────

  /// Events this module publishes. Purely declarative — enforced in debug mode.
  List<Type> get publishedEvents => const [];

  /// Events this module subscribes to. Purely declarative.
  List<Type> get subscribedEvents => const [];

  // ─── Internal State ────────────────────────────────────────────────────────

  ModuleEventBus? _eventBus;
  final List<StreamSubscription<dynamic>> _subscriptions = [];

  // ─── Framework Hooks ───────────────────────────────────────────────────────

  /// Injects the event bus. Called automatically by [ModuleRegistry].
  // ignore: use_setters_to_change_properties
  void attachEventBus(ModuleEventBus bus) {
    _eventBus = bus;
  }

  // ─── Public API ────────────────────────────────────────────────────────────

  /// Emits an event to the event bus.
  ///
  /// In debug mode, asserts that the event type is declared in [publishedEvents].
  void emit<T extends ModuleEvent>(T event) {
    assert(
      publishedEvents.isEmpty || publishedEvents.contains(T),
      '[$moduleId] Attempted to emit undeclared event $T. '
      'Add $T to publishedEvents list.',
    );
    _requireEventBus().emit(event);
  }

  /// Returns a typed stream of events of type [T].
  ///
  /// Automatically tracked — subscriptions are cancelled on [onDispose].
  Stream<T> on<T extends ModuleEvent>() {
    return _requireEventBus().on<T>();
  }

  /// Subscribes to events of type [T] with an optional filter.
  ///
  /// The subscription is automatically cancelled when the module disposes.
  StreamSubscription<T> listen<T extends ModuleEvent>(
    void Function(T event) handler, {
    bool Function(T event)? where,
  }) {
    var stream = on<T>();
    if (where != null) stream = stream.where(where);
    final sub = stream.listen(handler);
    _subscriptions.add(sub);
    return sub;
  }

  // ─── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  Future<void> onDispose() async {
    for (final sub in _subscriptions) {
      await sub.cancel();
    }
    _subscriptions.clear();
    await super.onDispose();
  }

  // ─── Private ───────────────────────────────────────────────────────────────

  ModuleEventBus _requireEventBus() {
    assert(
      _eventBus != null,
      '[$moduleId] EventBus not attached. '
      'Ensure the module is registered via MicrofrontendApp.',
    );
    return _eventBus!;
  }
}

// ─── Typed Event Subscription Helper ────────────────────────────────────────

/// Declarative subscription descriptor used by [EventAwareModule].
class EventSubscription<T extends ModuleEvent> {
  final void Function(T event) handler;
  final bool Function(T event)? filter;
  final Duration? debounce;

  const EventSubscription({
    required this.handler,
    this.filter,
    this.debounce,
  });
}
