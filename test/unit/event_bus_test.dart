import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_microfrontend/flutter_microfrontend.dart';

// Test event types
class PingEvent extends ModuleEvent {
  final int value;
  PingEvent(this.value, {super.sourceModuleId = 'test'});
  @override List<Object?> get props => [...super.props, value];
}

class PongEvent extends ModuleEvent {
  final String message;
  PongEvent(this.message, {super.sourceModuleId = 'test'});
  @override List<Object?> get props => [...super.props, message];
}

void main() {
  group('ModuleEventBus', () {
    late ModuleEventBus bus;

    setUp(() => bus = ModuleEventBus());
    tearDown(() => bus.dispose());

    // ─── Basic Pub/Sub ────────────────────────────────────────────────────

    test('should deliver events to subscribers', () async {
      final received = <PingEvent>[];
      bus.on<PingEvent>().listen(received.add);

      bus.emit(PingEvent(1));
      bus.emit(PingEvent(2));
      bus.emit(PingEvent(3));

      await Future.microtask(() {});

      expect(received.length, equals(3));
      expect(received.map((e) => e.value), containsAllInOrder([1, 2, 3]));
    });

    test('should NOT deliver wrong event types to subscribers', () async {
      final pingEvents = <PingEvent>[];
      final pongEvents = <PongEvent>[];

      bus.on<PingEvent>().listen(pingEvents.add);
      bus.on<PongEvent>().listen(pongEvents.add);

      bus.emit(PingEvent(42));
      await Future.microtask(() {});

      expect(pingEvents.length, equals(1));
      expect(pongEvents.length, equals(0));
    });

    test('should support multiple independent subscribers', () async {
      final sub1 = <PingEvent>[];
      final sub2 = <PingEvent>[];
      final sub3 = <PingEvent>[];

      bus.on<PingEvent>().listen(sub1.add);
      bus.on<PingEvent>().listen(sub2.add);
      bus.on<PingEvent>().listen(sub3.add);

      bus.emit(PingEvent(99));
      await Future.microtask(() {});

      expect(sub1.length, equals(1));
      expect(sub2.length, equals(1));
      expect(sub3.length, equals(1));
    });

    // ─── Stats ────────────────────────────────────────────────────────────

    test('should track total emitted event count', () {
      bus.emit(PingEvent(1));
      bus.emit(PingEvent(2));
      bus.emit(PongEvent('hi'));

      expect(bus.stats.totalEmitted, equals(3));
    });

    test('should track per-type event counts', () {
      bus.emit(PingEvent(1));
      bus.emit(PingEvent(2));
      bus.emit(PongEvent('hi'));

      expect(bus.stats.typeCounters[PingEvent], equals(2));
      expect(bus.stats.typeCounters[PongEvent], equals(1));
    });

    // ─── Subscribe with options ───────────────────────────────────────────

    test('subscribe with where filter', () async {
      final received = <PingEvent>[];
      bus.subscribe<PingEvent>(
        onEvent: received.add,
        where: (e) => e.value > 5,
      );

      bus.emit(PingEvent(3));
      bus.emit(PingEvent(7));
      bus.emit(PingEvent(1));
      bus.emit(PingEvent(10));

      await Future.microtask(() {});

      expect(received.map((e) => e.value), containsAllInOrder([7, 10]));
    });

    // ─── History ─────────────────────────────────────────────────────────

    test('should keep recent event history', () {
      for (int i = 0; i < 10; i++) {
        bus.emit(PingEvent(i));
      }
      final history = bus.recentEvents(count: 5);
      expect(history.length, equals(5));
    });

    // ─── EventChannel ─────────────────────────────────────────────────────

    test('EventChannel should receive events from bus', () async {
      final channel = EventChannel<PingEvent>(bus);
      final received = <PingEvent>[];
      channel.stream.listen(received.add);

      bus.emit(PingEvent(55));
      await Future.microtask(() {});

      expect(received.length, equals(1));
      expect(received.first.value, equals(55));

      await channel.dispose();
    });
  });
}
