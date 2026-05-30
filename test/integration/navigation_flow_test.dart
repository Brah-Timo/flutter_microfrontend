// ignore_for_file: lines_longer_than_80_chars

import 'package:flutter/material.dart';
import 'package:flutter_microfrontend/flutter_microfrontend.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../mocks/mock_module.dart';

// ---------------------------------------------------------------------------
// Routable mock modules used throughout these integration tests
// ---------------------------------------------------------------------------

class _HomeModule extends MockModule with RoutableModule {
  _HomeModule()
      : super(
          moduleId: 'home',
          dependencies: [],
        );

  @override
  List<RouteBase> get routes => [
        GoRoute(
          path: '/home',
          builder: (context, state) => const Scaffold(
            body: Center(child: Text('Home Screen')),
          ),
        ),
        GoRoute(
          path: '/home/details/:id',
          builder: (context, state) => Scaffold(
            body: Center(
              child: Text('Detail ${state.pathParameters['id']}'),
            ),
          ),
        ),
      ];

  @override
  String get initialRoute => '/home';

  @override
  bool get isRootDestination => true;

  @override
  int get navigationOrder => 0;
}

class _ShopModule extends MockModule with RoutableModule {
  _ShopModule()
      : super(
          moduleId: 'shop',
          dependencies: [],
        );

  @override
  List<RouteBase> get routes => [
        GoRoute(
          path: '/shop',
          builder: (context, state) => const Scaffold(
            body: Center(child: Text('Shop Screen')),
          ),
        ),
        GoRoute(
          path: '/shop/product/:sku',
          builder: (context, state) => Scaffold(
            body: Center(
              child: Text('Product ${state.pathParameters['sku']}'),
            ),
          ),
        ),
      ];

  @override
  String get initialRoute => '/shop';

  @override
  bool get isRootDestination => true;

  @override
  int get navigationOrder => 1;
}

class _AuthModule extends MockModule with RoutableModule {
  _AuthModule()
      : super(
          moduleId: 'auth',
          dependencies: [],
        );

  @override
  List<RouteBase> get routes => [
        GoRoute(
          path: '/login',
          builder: (context, state) => const Scaffold(
            body: Center(child: Text('Login Screen')),
          ),
        ),
        GoRoute(
          path: '/register',
          builder: (context, state) => const Scaffold(
            body: Center(child: Text('Register Screen')),
          ),
        ),
      ];

  @override
  String get initialRoute => '/login';

  @override
  bool get isRootDestination => false;

  @override
  int get navigationOrder => -1;
}

// ---------------------------------------------------------------------------
// Integration tests
// ---------------------------------------------------------------------------

void main() {
  group('Navigation Flow Integration', () {
    late ModuleRegistry registry;
    late GlobalInjector globalInjector;
    late ModuleEventBus eventBus;

    setUp(() {
      registry = ModuleRegistry.instance;
      globalInjector = GlobalInjector();
      eventBus = ModuleEventBus();
    });

    tearDown(() async {
      await registry.dispose();
      globalInjector.dispose();
      await eventBus.dispose();
    });

    // -----------------------------------------------------------------------
    // 1. getAllRoutes returns routes from all RoutableModules
    // -----------------------------------------------------------------------
    test(
      'getAllRoutes aggregates routes from every RoutableModule',
      () async {
        await registry.initialize(
          modules: [_HomeModule(), _ShopModule(), _AuthModule()],
          globalInjector: globalInjector,
          eventBus: eventBus,
        );

        final routes = registry.getAllRoutes();

        // 2 + 2 + 2 = 6 routes
        expect(routes.length, equals(6));
      },
    );

    // -----------------------------------------------------------------------
    // 2. getRootDestinations filters only isRootDestination == true
    // -----------------------------------------------------------------------
    test(
      'getRootDestinations returns only modules with isRootDestination = true',
      () async {
        await registry.initialize(
          modules: [_HomeModule(), _ShopModule(), _AuthModule()],
          globalInjector: globalInjector,
          eventBus: eventBus,
        );

        final roots = registry.getRootDestinations();

        expect(roots.length, equals(2));
        expect(
          roots.map((r) => r.moduleId).toSet(),
          containsAll(['home', 'shop']),
        );
      },
    );

    // -----------------------------------------------------------------------
    // 3. Root destinations are sorted by navigationOrder
    // -----------------------------------------------------------------------
    test(
      'getRootDestinations returns destinations sorted by navigationOrder',
      () async {
        await registry.initialize(
          modules: [_HomeModule(), _ShopModule()],
          globalInjector: globalInjector,
          eventBus: eventBus,
        );

        final roots = registry.getRootDestinations();

        expect(roots.first.moduleId, equals('home'));
        expect(roots.last.moduleId, equals('shop'));
      },
    );

    // -----------------------------------------------------------------------
    // 4. ModuleRouter builds a GoRouter from the registry
    // -----------------------------------------------------------------------
    test(
      'ModuleRouter.goRouter is a valid GoRouter with collected routes',
      () async {
        await registry.initialize(
          modules: [_HomeModule(), _ShopModule()],
          globalInjector: globalInjector,
          eventBus: eventBus,
        );

        final moduleRouter = ModuleRouter(
          registry: registry,
          config: const ModuleRouterConfig(initialLocation: '/home'),
        );

        expect(moduleRouter.goRouter, isA<GoRouter>());
        // The router configuration list must contain all 4 routes + catch-all
        expect(
          moduleRouter.goRouter.configuration.routes.length,
          greaterThanOrEqualTo(4),
        );
      },
    );

    // -----------------------------------------------------------------------
    // 5. Route deduplication — duplicate modules throw
    // -----------------------------------------------------------------------
    test(
      'Registering the same moduleId twice throws DuplicateModuleException',
      () async {
        await expectLater(
          registry.initialize(
            modules: [_HomeModule(), _HomeModule()],
            globalInjector: globalInjector,
            eventBus: eventBus,
          ),
          throwsA(isA<DuplicateModuleException>()),
        );
      },
    );

    // -----------------------------------------------------------------------
    // 6. Unregistered module's routes are removed from router
    // -----------------------------------------------------------------------
    test(
      'Routes from unregistered module disappear from getAllRoutes',
      () async {
        await registry.initialize(
          modules: [_HomeModule(), _ShopModule()],
          globalInjector: globalInjector,
          eventBus: eventBus,
        );
        final before = registry.getAllRoutes().length;

        await registry.unregister('shop');
        final after = registry.getAllRoutes().length;

        expect(after, equals(before - 2),
            reason: 'shop contributed 2 routes which should be removed');
      },
    );

    // -----------------------------------------------------------------------
    // 7. Widget integration: GoRouter navigates to rendered screen
    // -----------------------------------------------------------------------
    testWidgets(
      'GoRouter built from ModuleRouter navigates to correct screen',
      (tester) async {
        await registry.initialize(
          modules: [_HomeModule(), _ShopModule()],
          globalInjector: globalInjector,
          eventBus: eventBus,
        );

        final moduleRouter = ModuleRouter(
          registry: registry,
          config: const ModuleRouterConfig(initialLocation: '/home'),
        );

        await tester.pumpWidget(
          MaterialApp.router(
            routerConfig: moduleRouter.goRouter,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Home Screen'), findsOneWidget);
      },
    );
  });
}
