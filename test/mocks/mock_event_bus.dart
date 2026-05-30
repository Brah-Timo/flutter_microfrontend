import 'package:flutter_microfrontend/flutter_microfrontend.dart';

/// A [ModuleEventBus] subclass that records all emitted events.
class MockEventBus extends ModuleEventBus {
  final List<ModuleEvent> emittedEvents = [];

  @override
  void emit(ModuleEvent event) {
    emittedEvents.add(event);
    super.emit(event);
  }

  /// Returns all events of type [T].
  List<T> eventsOfType<T extends ModuleEvent>() =>
      emittedEvents.whereType<T>().toList();

  /// Clears recorded events.
  void clear() => emittedEvents.clear();
}
