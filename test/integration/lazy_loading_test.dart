// ignore_for_file: lines_longer_than_80_chars

import 'package:flutter_microfrontend/flutter_microfrontend.dart';
import 'package:flutter_test/flutter_test.dart';

import '../mocks/mock_module.dart';

// ---------------------------------------------------------------------------
// Integration tests — match the actual DeferredModule / ModuleLoader API
// ---------------------------------------------------------------------------

void main() {
  group('Lazy Loading Integration', () {
    // -----------------------------------------------------------------------
    // 1. DeferredModule loads exactly once (idempotency)
    // -----------------------------------------------------------------------
    test(
      'DeferredModule loads exactly once even with concurrent calls',
      () async {
        int callCount = 0;
        final inner = MockModule(moduleId: 'lazy_once');
        final deferred = DeferredModule(
          moduleId: 'lazy_once',
          loader: () async {
            callCount++;
            await Future<void>.delayed(const Duration(milliseconds: 20));
            return inner;
          },
        );

        // Fire 5 concurrent loads
        final results = await Future.wait(
          List.generate(5, (_) => deferred.load()),
        );

        expect(results.every((m) => m == inner), isTrue,
            reason: 'All concurrent loads should return the same instance');
        expect(callCount, equals(1),
            reason: 'Factory must be called exactly once');
        expect(deferred.isLoaded, isTrue);
      },
    );

    // -----------------------------------------------------------------------
    // 2. DeferredModule retries on transient failure
    // -----------------------------------------------------------------------
    test(
      'DeferredModule retries and succeeds after transient failure',
      () async {
        int attemptCount = 0;
        final inner = MockModule(moduleId: 'retry_module');
        final deferred = DeferredModule(
          moduleId: 'retry_module',
          loader: () async {
            attemptCount++;
            if (attemptCount == 1) {
              throw StateError('Transient error');
            }
            return inner;
          },
          config: const PreloadConfig(
            maxRetries: 3,
            retryDelay: Duration(milliseconds: 10),
          ),
        );

        final loaded = await deferred.load();

        expect(loaded, equals(inner));
        expect(attemptCount, equals(2),
            reason: 'Should succeed on second attempt');
      },
    );

    // -----------------------------------------------------------------------
    // 3. DeferredModule unload then reload creates fresh instance
    // -----------------------------------------------------------------------
    test(
      'DeferredModule can be unloaded and reloaded',
      () async {
        int factoryCallCount = 0;
        final deferred = DeferredModule(
          moduleId: 'reloadable',
          loader: () async {
            factoryCallCount++;
            return MockModule(moduleId: 'reloadable');
          },
        );

        final first = await deferred.load();
        expect(deferred.isLoaded, isTrue);

        await deferred.unload();
        expect(deferred.isLoaded, isFalse);

        final second = await deferred.load();
        expect(deferred.isLoaded, isTrue);

        expect(factoryCallCount, equals(2),
            reason: 'Factory called again after unload');
        expect(identical(first, second), isFalse,
            reason: 'Fresh instance after reload');
      },
    );

    // -----------------------------------------------------------------------
    // 4. PreloadStrategy.afterAppReady is stored correctly
    // -----------------------------------------------------------------------
    test(
      'DeferredModule stores preloadStrategy correctly',
      () {
        final deferred = DeferredModule(
          moduleId: 'strategy_mod',
          loader: () async => MockModule(moduleId: 'strategy_mod'),
          preloadStrategy: PreloadStrategy.afterAppReady,
        );

        expect(deferred.preloadStrategy, equals(PreloadStrategy.afterAppReady));
        expect(deferred.isLoaded, isFalse);
      },
    );

    // -----------------------------------------------------------------------
    // 5. ModuleLoader triggers loads for matching strategies
    // -----------------------------------------------------------------------
    test(
      'ModuleLoader.onAppReady loads afterAppReady DeferredModules',
      () async {
        final loader = ModuleLoader();
        final mod1 = MockModule(moduleId: 'loader_mod_1');
        final mod2 = MockModule(moduleId: 'loader_mod_2');

        final deferred1 = DeferredModule(
          moduleId: 'loader_mod_1',
          loader: () async => mod1,
          preloadStrategy: PreloadStrategy.afterAppReady,
        );
        final deferred2 = DeferredModule(
          moduleId: 'loader_mod_2',
          loader: () async => mod2,
          preloadStrategy: PreloadStrategy.onDemand,
        );

        loader
          ..register(deferred1)
          ..register(deferred2);

        await loader.onAppReady();

        expect(deferred1.isLoaded, isTrue,
            reason: 'afterAppReady module should be loaded');
        expect(deferred2.isLoaded, isFalse,
            reason: 'onDemand module should not be loaded yet');

        loader.dispose();
      },
    );

    // -----------------------------------------------------------------------
    // 6. DeferredModule diagnostics report correct information
    // -----------------------------------------------------------------------
    test(
      'DeferredModule diagnostics expose accurate load info',
      () async {
        final deferred = DeferredModule(
          moduleId: 'diag_module',
          loader: () async {
            await Future<void>.delayed(const Duration(milliseconds: 30));
            return MockModule(moduleId: 'diag_module');
          },
          preloadStrategy: PreloadStrategy.onDemand,
        );

        await deferred.load();

        final diag = deferred.diagnostics;
        expect(diag.isLoaded, isTrue);
        expect(diag.moduleId, equals('diag_module'));
        expect(diag.loadAttempts, equals(1));
        expect(diag.preloadStrategy, equals(PreloadStrategy.onDemand));
        expect(diag.loadedAt, isNotNull);
      },
    );
  });
}
