import 'package:go_router/go_router.dart';
import 'module_contract.dart';

/// Mixin for modules that expose navigation routes.
///
/// Any module that renders screens must implement this mixin.
/// The [ModuleRegistry] automatically collects all routes from registered
/// [RoutableModule]s and registers them with [ModuleRouter].
///
/// ## Example
/// ```dart
/// class ShopModule extends MicroModule with RoutableModule {
///   @override String get moduleId => 'shop';
///   @override String get moduleName => 'Shop';
///
///   @override
///   List<RouteBase> get routes => [
///     GoRoute(
///       path: '/shop',
///       builder: (ctx, state) => const ShopHomePage(),
///       routes: [
///         GoRoute(
///           path: 'product/:id',
///           builder: (ctx, state) => ProductPage(
///             id: state.pathParameters['id']!,
///           ),
///         ),
///       ],
///     ),
///   ];
/// }
/// ```
mixin RoutableModule on MicroModule {
  // ─── Required ──────────────────────────────────────────────────────────────

  /// All routes provided by this module.
  ///
  /// Routes are independent — they should not reference paths from other
  /// modules directly. Use [ModuleNavigationContract] for cross-module navigation.
  List<RouteBase> get routes;

  // ─── Optional ──────────────────────────────────────────────────────────────

  /// The default entry-point path for this module.
  ///
  /// Used for deep-linking and bottom navigation initial destinations.
  String? get initialRoute => null;

  /// Whether this module represents a top-level navigation destination
  /// (i.e., shown in the bottom navigation bar or drawer).
  bool get isRootDestination => false;

  /// Navigation icon data for bottom nav / drawer (if [isRootDestination]).
  ///
  /// Use the icon name from `package:flutter/material.dart` Icons class.
  /// e.g. `'shopping_cart'`, `'home'`, `'settings'`
  String? get navigationIconName => null;

  /// Label shown in the bottom navigation bar (if [isRootDestination]).
  String? get navigationLabel => null;

  /// Navigation order in the bottom bar (lower = first).
  int get navigationOrder => 100;

  /// Route guards — evaluated before entering any route in this module.
  ///
  /// Return a redirect path (e.g., `/login`) to block access,
  /// or `null` to allow.
  Future<String?> guardRoutes(String targetPath) async => null;
}
