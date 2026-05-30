import 'package:flutter/widgets.dart';
import '../core/module_registry.dart';
import '../events/event_bus.dart';
import '../state/module_state_scope.dart';

/// Establishes a clear boundary in the widget tree for a specific module.
///
/// [ModuleBoundary] does two things:
/// 1. Injects [ModuleStateScope] with the module's DI container and event bus
/// 2. Provides a named semantic boundary for debugging (visible in Flutter DevTools)
///
/// ```dart
/// GoRoute(
///   path: '/shop',
///   builder: (ctx, state) => ModuleBoundary(
///     moduleId: 'shop',
///     child: const ShopHomePage(),
///   ),
/// )
/// ```
class ModuleBoundary extends StatelessWidget {
  final String moduleId;
  final Widget child;
  final bool showDebugLabel;

  const ModuleBoundary({
    super.key,
    required this.moduleId,
    required this.child,
    this.showDebugLabel = false,
  });

  @override
  Widget build(BuildContext context) {
    final registry = ModuleRegistry.instance;
    final injector = registry.getInjector(moduleId);

    assert(
      injector != null,
      'ModuleBoundary: module "$moduleId" is not registered or not yet ready. '
      'Make sure the module is initialized before creating its boundary.',
    );

    return _ModuleBoundaryMarker(
      moduleId: moduleId,
      child: ModuleStateScope(
        moduleId: moduleId,
        injector: injector!,
        eventBus: _getEventBus(context),
        child: showDebugLabel
            ? _DebugBoundaryLabel(moduleId: moduleId, child: child)
            : child,
      ),
    );
  }

  ModuleEventBus _getEventBus(BuildContext context) {
    // Access from parent ModuleStateScope if available
    return ModuleStateScope.maybeOf(context)?.eventBus ??
        _FallbackEventBus();
  }
}

/// Invisible marker widget for DevTools identification.
class _ModuleBoundaryMarker extends StatelessWidget {
  final String moduleId;
  final Widget child;

  const _ModuleBoundaryMarker({
    required this.moduleId,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => child;

  @override
  String toStringShort() => 'ModuleBoundary[$moduleId]';
}

class _DebugBoundaryLabel extends StatelessWidget {
  final String moduleId;
  final Widget child;

  const _DebugBoundaryLabel({
    required this.moduleId,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Positioned(
          top: 0,
          right: 0,
          child: _DebugTag(label: moduleId),
        ),
      ],
    );
  }
}

class _DebugTag extends StatelessWidget {
  final String label;
  const _DebugTag({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0x88FF5722),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          color: Color(0xFFFFFFFF),
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// Fallback event bus — used when no parent scope provides one.
class _FallbackEventBus extends ModuleEventBus {}
