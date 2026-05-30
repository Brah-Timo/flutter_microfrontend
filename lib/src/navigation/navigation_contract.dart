/// Navigation contract for cross-module navigation.
///
/// Modules must NOT import each other's route paths directly.
/// Instead, use named routes or this contract to navigate between modules.
///
/// ```dart
/// // BAD — creates coupling between modules:
/// context.go('/shop/product/123');
///
/// // GOOD — use the registry or well-known named routes:
/// ModuleNavigator.of(context).goTo(ShopRoutes.product('123'));
/// ```
abstract class ModuleNavigationContract {
  /// Navigate to a named route defined by another module.
  Future<void> goTo(String path, {Map<String, String>? params});

  /// Push a named route onto the navigation stack.
  Future<T?> pushTo<T>(String path, {Map<String, String>? params});

  /// Replace current route with a named route.
  Future<void> replaceTo(String path, {Map<String, String>? params});

  /// Pop back to the previous route.
  void pop<T>([T? result]);

  /// Check if a given path can be navigated to.
  bool canNavigateTo(String path);
}

// ─── Well-known Route Paths ───────────────────────────────────────────────────

/// Static route path constants to avoid magic strings across modules.
///
/// Each module can extend this with its own routes:
/// ```dart
/// extension ShopRoutes on ModuleRoutes {
///   static String get home => '/shop';
///   static String product(String id) => '/shop/product/$id';
/// }
/// ```
abstract class ModuleRoutes {
  /// The app's initial (home) route.
  static const String home = '/';

  /// A generic "not found" route.
  static const String notFound = '/404';
}
