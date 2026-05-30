import 'package:flutter/widgets.dart';
import '../injection/module_injector.dart';
import '../events/event_bus.dart';

/// Provides module-scoped state context to all descendants.
///
/// Place this at the root of each module's widget tree to make the module's
/// [ModuleInjector] and [ModuleEventBus] accessible via [BuildContext].
///
/// ```dart
/// // In your module's root route builder:
/// GoRoute(
///   path: '/shop',
///   builder: (ctx, state) => ModuleStateScope(
///     moduleId: 'shop',
///     injector: injector,
///     eventBus: eventBus,
///     child: const ShopHomePage(),
///   ),
/// )
/// ```
class ModuleStateScope extends InheritedWidget {
  final String moduleId;
  final ModuleInjector injector;
  final ModuleEventBus eventBus;

  const ModuleStateScope({
    super.key,
    required this.moduleId,
    required this.injector,
    required this.eventBus,
    required super.child,
  });

  /// Returns the nearest [ModuleStateScope] above [context].
  static ModuleStateScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ModuleStateScope>();
  }

  /// Returns the nearest [ModuleStateScope] or throws if not found.
  static ModuleStateScope of(BuildContext context) {
    final scope = maybeOf(context);
    assert(
      scope != null,
      'No ModuleStateScope found above this context. '
      'Wrap your module root with ModuleStateScope.',
    );
    return scope!;
  }

  @override
  bool updateShouldNotify(ModuleStateScope oldWidget) =>
      oldWidget.moduleId != moduleId ||
      oldWidget.injector != injector ||
      oldWidget.eventBus != eventBus;
}

// ─── Extension ───────────────────────────────────────────────────────────────

extension ModuleStateScopeExtension on BuildContext {
  /// Returns the current module's [ModuleInjector].
  ModuleInjector get moduleInjector => ModuleStateScope.of(this).injector;

  /// Returns the current module's [ModuleEventBus].
  ModuleEventBus get moduleEventBus => ModuleStateScope.of(this).eventBus;

  /// Returns the current module's ID.
  String get moduleId => ModuleStateScope.of(this).moduleId;

  /// Shortcut to get a service from the module's DI container.
  T moduleGet<T extends Object>({String? name}) =>
      moduleInjector.get<T>(instanceName: name);
}
