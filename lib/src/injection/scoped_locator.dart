import 'package:flutter/widgets.dart';
import 'module_injector.dart';
import 'global_injector.dart';

/// An [InheritedWidget] that exposes a module's injector to its widget subtree.
///
/// Placed at the root of a module's widget tree, it allows any descendant
/// widget to access module-scoped services without prop-drilling.
///
/// ```dart
/// // In module's root widget:
/// @override
/// Widget build(BuildContext context) {
///   return ScopedLocator(
///     injector: widget.injector,
///     child: const ShopHomePage(),
///   );
/// }
///
/// // In any descendant widget:
/// final cartService = ScopedLocator.of(context).get<CartService>();
/// ```
class ScopedLocator extends InheritedWidget {
  final ModuleInjector injector;

  const ScopedLocator({
    super.key,
    required this.injector,
    required super.child,
  });

  /// Returns the nearest [ScopedLocator]'s injector.
  ///
  /// Throws if no [ScopedLocator] is found in the widget tree.
  static ModuleInjector of(BuildContext context) {
    final result =
        context.dependOnInheritedWidgetOfExactType<ScopedLocator>();
    assert(
      result != null,
      'No ScopedLocator found in context. '
      'Wrap your module root widget with ScopedLocator.',
    );
    return result!.injector;
  }

  /// Returns the nearest [ScopedLocator]'s injector, or null if not found.
  static ModuleInjector? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<ScopedLocator>()
        ?.injector;
  }

  /// Shortcut to get a service from the scoped injector.
  static T get<T extends Object>(BuildContext context, {String? name}) {
    return of(context).get<T>(instanceName: name);
  }

  @override
  bool updateShouldNotify(ScopedLocator oldWidget) =>
      oldWidget.injector != injector;
}

// ─── Convenience Extension ────────────────────────────────────────────────────

extension ScopedLocatorExtension on BuildContext {
  /// Retrieve a service from the nearest [ScopedLocator] in the tree.
  T read<T extends Object>({String? name}) {
    return ScopedLocator.of(this).get<T>(instanceName: name);
  }

  /// Try to retrieve a service — returns null if not found.
  T? tryRead<T extends Object>({String? name}) {
    return ScopedLocator.maybeOf(this)?.tryGet<T>(instanceName: name);
  }
}

// ─── Global Locator Extension ─────────────────────────────────────────────────

/// Provides access to the [GlobalInjector] from any BuildContext
/// without requiring [ScopedLocator] in the tree.
///
/// Only use for truly global services (HttpClient, Config, etc.).
class GlobalLocator extends InheritedWidget {
  final GlobalInjector injector;

  const GlobalLocator({
    super.key,
    required this.injector,
    required super.child,
  });

  static GlobalInjector of(BuildContext context) {
    final result =
        context.dependOnInheritedWidgetOfExactType<GlobalLocator>();
    assert(result != null, 'No GlobalLocator found in context.');
    return result!.injector;
  }

  static T get<T extends Object>(BuildContext context, {String? name}) {
    return of(context).get<T>(instanceName: name);
  }

  @override
  bool updateShouldNotify(GlobalLocator oldWidget) =>
      oldWidget.injector != injector;
}
