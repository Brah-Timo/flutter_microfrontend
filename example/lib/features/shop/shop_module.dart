import 'package:flutter/material.dart';
import 'package:flutter_microfrontend/flutter_microfrontend.dart';
import 'package:go_router/go_router.dart';
import 'screens/shop_screen.dart';
import 'screens/product_detail_screen.dart';

/// Shop module — product catalog, cart, checkout.
/// This module is LAZY LOADED — its code is not executed until first visit.
class ShopModule extends MicroModule with RoutableModule {
  @override
  String get moduleId => 'shop';

  @override
  String get moduleName => 'Shop';

  @override
  String get description => 'Product catalog and shopping cart';

  @override
  List<String> get dependencies => ['auth'];

  @override
  bool get isRootDestination => true;

  @override
  String? get navigationIconName => 'shopping_bag';

  @override
  String? get navigationLabel => 'Shop';

  @override
  int get navigationOrder => 2;

  @override
  Future<void> onInit() async {
    await super.onInit();
    // Initialize shop-specific services
    debugPrint('[ShopModule] ✅ Initialized (lazy loaded successfully)');
  }

  @override
  List<RouteBase> get routes => [
        GoRoute(
          path: '/shop',
          name: 'shop',
          builder: (ctx, state) => const ShopScreen(),
          routes: [
            GoRoute(
              path: 'product/:id',
              name: 'product-detail',
              builder: (ctx, state) => ProductDetailScreen(
                productId: state.pathParameters['id'] ?? '',
              ),
            ),
          ],
        ),
      ];

  @override
  String get initialRoute => '/shop';
}
