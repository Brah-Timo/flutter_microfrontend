import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_microfrontend/flutter_microfrontend.dart';
import '../mocks/mock_module.dart';

void main() {
  group('DeferredModule', () {
    // ─── Basics ──────────────────────────────────────────────────────────

    test('is not loaded initially', () {
      final deferred = DeferredModule(
        moduleId: 'lazy-test',
        loader: () async => MockModule(moduleId: 'lazy-test'),
      );
      expect(deferred.isLoaded, isFalse);
      expect(deferred.isLoading, isFalse);
      expect(deferred.loadedModule, isNull);
    });

    test('loads successfully on first call', () async {
      final inner = MockModule(moduleId: 'lazy-test');
      final deferred = DeferredModule(
        moduleId: 'lazy-test',
        loader: () async => inner,
      );

      final result = await deferred.load();

      expect(result, equals(inner));
      expect(deferred.isLoaded, isTrue);
      expect(deferred.loadedModule, equals(inner));
    });

    test('returns same instance on repeated load calls', () async {
      int callCount = 0;
      final deferred = DeferredModule(
        moduleId: 'lazy-test',
        loader: () async {
          callCount++;
          return MockModule(moduleId: 'lazy-test');
        },
      );

      final r1 = await deferred.load();
      final r2 = await deferred.load();

      expect(identical(r1, r2), isTrue);
      expect(callCount, equals(1));
    });

    test('concurrent load calls resolve to same future', () async {
      var callCount = 0;
      final deferred = DeferredModule(
        moduleId: 'lazy-test',
        loader: () async {
          callCount++;
          await Future<void>.delayed(const Duration(milliseconds: 50));
          return MockModule(moduleId: 'lazy-test');
        },
      );

      final futures = [deferred.load(), deferred.load(), deferred.load()];
      final results = await Future.wait(futures);

      expect(callCount, equals(1));
      expect(results.every((r) => identical(r, results.first)), isTrue);
    });

    // ─── Retry ───────────────────────────────────────────────────────────

    test('retries on failure and succeeds on second attempt', () async {
      int attempt = 0;
      final deferred = DeferredModule(
        moduleId: 'retry-test',
        loader: () async {
          attempt++;
          if (attempt < 2) throw Exception('Simulated failure');
          return MockModule(moduleId: 'retry-test');
        },
        config: const PreloadConfig(
          maxRetries: 3,
          retryDelay: Duration(milliseconds: 10),
        ),
      );

      final result = await deferred.load();
      expect(result.moduleId, equals('retry-test'));
      expect(attempt, equals(2));
    });

    test('throws after exhausting retries', () async {
      final deferred = DeferredModule(
        moduleId: 'fail-test',
        loader: () async => throw Exception('Always fails'),
        config: const PreloadConfig(
          maxRetries: 2,
          retryDelay: Duration(milliseconds: 5),
          loadTimeout: Duration(seconds: 5),
        ),
      );

      await expectLater(deferred.load(), throwsA(isA<Exception>()));
      expect(deferred.isLoaded, isFalse);
    });

    // ─── Unload ──────────────────────────────────────────────────────────

    test('can unload and reload', () async {
      int loadCount = 0;
      final deferred = DeferredModule(
        moduleId: 'unload-test',
        loader: () async {
          loadCount++;
          return MockModule(moduleId: 'unload-test');
        },
      );

      await deferred.load();
      expect(deferred.isLoaded, isTrue);
      expect(loadCount, equals(1));

      await deferred.unload();
      expect(deferred.isLoaded, isFalse);

      await deferred.load();
      expect(loadCount, equals(2));
    });

    // ─── Diagnostics ─────────────────────────────────────────────────────

    test('diagnostics expose module info', () async {
      final deferred = DeferredModule(
        moduleId: 'diag-test',
        loader: () async => MockModule(moduleId: 'diag-test'),
        preloadStrategy: PreloadStrategy.onDemand,
      );

      await deferred.load();

      final diag = deferred.diagnostics;
      expect(diag.moduleId, equals('diag-test'));
      expect(diag.isLoaded, isTrue);
      expect(diag.loadAttempts, equals(1));
      expect(diag.preloadStrategy, equals(PreloadStrategy.onDemand));
    });
  });
}
