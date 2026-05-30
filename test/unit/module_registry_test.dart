import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_microfrontend/flutter_microfrontend.dart';
import '../mocks/mock_module.dart';
import '../mocks/mock_event_bus.dart';

void main() {
  group('ModuleRegistry', () {
    late ModuleRegistry registry;
    late GlobalInjector globalInjector;
    late MockEventBus eventBus;

    setUp(() {
      // ModuleRegistry is a singleton — dispose it between tests
      registry = ModuleRegistry.instance;
      globalInjector = GlobalInjector();
      eventBus = MockEventBus();
    });

    tearDown(() async {
      await registry.dispose();
      globalInjector.dispose();
      await eventBus.dispose();
    });

    // ─── Basic Registration ──────────────────────────────────────────────────

    test('should register a single module successfully', () async {
      final module = MockModule(moduleId: 'test-module', moduleName: 'Test');

      await registry.initialize(
        modules: [module],
        globalInjector: globalInjector,
        eventBus: eventBus,
      );

      expect(registry.isRegistered('test-module'), isTrue);
      expect(registry.isReady('test-module'), isTrue);
    });

    test('should call onRegister and onInit exactly once', () async {
      final module = MockModule(moduleId: 'test-module', moduleName: 'Test');

      await registry.initialize(
        modules: [module],
        globalInjector: globalInjector,
        eventBus: eventBus,
      );

      expect(module.registerCount, equals(1));
      expect(module.initCount, equals(1));
    });

    test('should register multiple modules', () async {
      final modules = [
        MockModule(moduleId: 'mod-a', moduleName: 'A'),
        MockModule(moduleId: 'mod-b', moduleName: 'B'),
        MockModule(moduleId: 'mod-c', moduleName: 'C'),
      ];

      await registry.initialize(
        modules: modules,
        globalInjector: globalInjector,
        eventBus: eventBus,
      );

      for (final m in modules) {
        expect(registry.isRegistered(m.moduleId), isTrue);
      }
    });

    // ─── Dependency Order ────────────────────────────────────────────────────

    test('should initialize modules in dependency order', () async {
      final initOrder = <String>[];

      final base = MockModule(
        moduleId: 'base-module',
        moduleName: 'Base',
        onInitCallback: () => initOrder.add('base-module'),
      );
      final feature = MockModule(
        moduleId: 'feature-module',
        moduleName: 'Feature',
        dependencies: ['base-module'],
        onInitCallback: () => initOrder.add('feature-module'),
      );

      // Intentionally add feature before base
      await registry.initialize(
        modules: [feature, base],
        globalInjector: globalInjector,
        eventBus: eventBus,
      );

      expect(
        initOrder.indexOf('base-module'),
        lessThan(initOrder.indexOf('feature-module')),
        reason: 'base-module must be initialized before feature-module',
      );
    });

    // ─── Circular Dependencies ───────────────────────────────────────────────

    test('should throw CircularDependencyException for circular deps',
        () async {
      final a = MockModule(
        moduleId: 'module-a',
        moduleName: 'A',
        dependencies: ['module-b'],
      );
      final b = MockModule(
        moduleId: 'module-b',
        moduleName: 'B',
        dependencies: ['module-a'],
      );

      await expectLater(
        registry.initialize(
          modules: [a, b],
          globalInjector: globalInjector,
          eventBus: eventBus,
        ),
        throwsA(isA<CircularDependencyException>()),
      );
    });

    // ─── Duplicate Registration ──────────────────────────────────────────────

    test('should throw DuplicateModuleException for duplicate IDs', () async {
      final m1 = MockModule(moduleId: 'dup-module', moduleName: 'Dup 1');
      final m2 = MockModule(moduleId: 'dup-module', moduleName: 'Dup 2');

      await expectLater(
        registry.initialize(
          modules: [m1, m2],
          globalInjector: globalInjector,
          eventBus: eventBus,
        ),
        throwsA(isA<DuplicateModuleException>()),
      );
    });

    // ─── Dynamic Registration ────────────────────────────────────────────────

    test('should register a dynamic module after startup', () async {
      await registry.initialize(
        modules: [],
        globalInjector: globalInjector,
        eventBus: eventBus,
      );

      final dynamicModule =
          MockModule(moduleId: 'dynamic-module', moduleName: 'Dynamic');
      await registry.registerDynamic(dynamicModule);

      expect(registry.isRegistered('dynamic-module'), isTrue);
      expect(registry.isReady('dynamic-module'), isTrue);
    });

    // ─── Unregister ──────────────────────────────────────────────────────────

    test('should call onDispose when unregistering a module', () async {
      final module =
          MockModule(moduleId: 'disposable', moduleName: 'Disposable');
      await registry.initialize(
        modules: [module],
        globalInjector: globalInjector,
        eventBus: eventBus,
      );

      await registry.unregister('disposable');

      expect(module.disposeCount, equals(1));
      expect(registry.isRegistered('disposable'), isFalse);
    });

    // ─── Lifecycle Forwarding ────────────────────────────────────────────────

    test('should forward pauseAll and resumeAll to modules', () async {
      final module =
          MockModule(moduleId: 'lifecycle-mod', moduleName: 'Lifecycle');
      await registry.initialize(
        modules: [module],
        globalInjector: globalInjector,
        eventBus: eventBus,
      );

      await registry.pauseAll();
      expect(module.pauseCount, equals(1));

      await registry.resumeAll();
      expect(module.resumeCount, equals(1));
    });

    // ─── Lifecycle Stream ────────────────────────────────────────────────────

    test('should emit lifecycle events on the lifecycleStream', () async {
      final events = <ModuleLifecycleEvent>[];
      final sub = registry.lifecycleStream.listen(events.add);

      final module =
          MockModule(moduleId: 'stream-test', moduleName: 'StreamTest');
      await registry.initialize(
        modules: [module],
        globalInjector: globalInjector,
        eventBus: eventBus,
      );

      await sub.cancel();

      expect(
        events.any((e) => e.state == ModuleLifecycleState.ready),
        isTrue,
      );
    });
  });
}
