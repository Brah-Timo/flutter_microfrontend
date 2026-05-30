import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_microfrontend/flutter_microfrontend.dart';
import '../mocks/mock_module.dart';

void main() {
  group('DependencyGraph', () {
    late DependencyGraph graph;

    setUp(() => graph = DependencyGraph());

    // ─── Topological Sort ────────────────────────────────────────────────

    test('returns single module unchanged', () {
      final m = MockModule(moduleId: 'only-module');
      graph.build([m]);
      final order = graph.getTopologicalOrder([m]);
      expect(order, contains(m));
    });

    test('puts dependency before dependent', () {
      final auth = MockModule(moduleId: 'auth');
      final home = MockModule(
        moduleId: 'home',
        dependencies: ['auth'],
      );

      graph.build([home, auth]);
      final order = graph.getTopologicalOrder([home, auth]);

      expect(order.indexOf(auth), lessThan(order.indexOf(home)));
    });

    test('handles multiple independent modules', () {
      final modules = [
        MockModule(moduleId: 'mod-x'),
        MockModule(moduleId: 'mod-y'),
        MockModule(moduleId: 'mod-z'),
      ];
      graph.build(modules);
      final order = graph.getTopologicalOrder(modules);
      expect(order.length, equals(3));
    });

    test('respects loadPriority within same level', () {
      final low = MockModule(moduleId: 'low-prio', loadPriority: 1);
      final high = MockModule(moduleId: 'high-prio', loadPriority: 100);

      graph.build([low, high]);
      final order = graph.getTopologicalOrder([low, high]);

      expect(order.indexOf(high), lessThan(order.indexOf(low)));
    });

    // ─── Cycle Detection ────────────────────────────────────────────────

    test('detects direct circular dependency (A → B → A)', () {
      final a = MockModule(moduleId: 'cycle-a', dependencies: ['cycle-b']);
      final b = MockModule(moduleId: 'cycle-b', dependencies: ['cycle-a']);

      graph.build([a, b]);
      expect(
        graph.checkForCircularDependencies,
        throwsA(isA<CircularDependencyException>()),
      );
    });

    test('detects transitive circular dependency (A → B → C → A)', () {
      final a = MockModule(moduleId: 'a', dependencies: ['b']);
      final b = MockModule(moduleId: 'b', dependencies: ['c']);
      final c = MockModule(moduleId: 'c', dependencies: ['a']);

      graph.build([a, b, c]);
      expect(
        graph.checkForCircularDependencies,
        throwsA(isA<CircularDependencyException>()),
      );
    });

    test('does not throw for valid dependency chain', () {
      final base = MockModule(moduleId: 'base');
      final mid = MockModule(moduleId: 'mid', dependencies: ['base']);
      final top = MockModule(moduleId: 'top', dependencies: ['mid']);

      graph.build([base, mid, top]);
      expect(graph.checkForCircularDependencies, returnsNormally);
    });

    // ─── Analysis ───────────────────────────────────────────────────────

    test('getDependents returns correct set', () {
      final auth = MockModule(moduleId: 'auth');
      final home = MockModule(moduleId: 'home', dependencies: ['auth']);
      final shop = MockModule(moduleId: 'shop', dependencies: ['auth']);

      graph.build([auth, home, shop]);
      final dependents = graph.getDependents('auth');

      expect(dependents, containsAll(['home', 'shop']));
    });
  });
}
