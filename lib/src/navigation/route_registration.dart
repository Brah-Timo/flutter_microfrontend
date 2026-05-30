import 'package:go_router/go_router.dart';
import '../contracts/routable_module.dart';
import '../contracts/module_contract.dart';
import '../utils/module_logger.dart';

/// Collects and assembles routes from all [RoutableModule]s.
///
/// Called internally by [ModuleRouter] during initialization.
class RouteRegistration {
  final _logger = ModuleLogger('RouteRegistration');

  /// Aggregates all routes from the given list of modules.
  ///
  /// Also sorts root destinations by [RoutableModule.navigationOrder].
  List<RouteBase> collectRoutes(List<MicroModule> modules) {
    final routes = <RouteBase>[];
    int routeCount = 0;

    for (final module in modules) {
      if (module is RoutableModule) {
        final moduleRoutes = module.routes;
        routes.addAll(moduleRoutes);
        routeCount += moduleRoutes.length;
        _logger.debug(
            '  ↳ ${module.moduleName}: ${moduleRoutes.length} route(s)');
      }
    }

    _logger.info(
        '📍 Collected $routeCount route(s) from '
        '${modules.where((m) => m is RoutableModule).length} module(s)');

    return routes;
  }

  /// Returns root destinations in display order.
  List<RootDestination> getRootDestinations(List<MicroModule> modules) {
    final destinations = <RootDestination>[];

    for (final module in modules) {
      if (module is RoutableModule) {
        if (module.isRootDestination) {
          destinations.add(RootDestination(
            moduleId: module.moduleId,
            label: module.navigationLabel ?? module.moduleName,
            iconName: module.navigationIconName ?? 'circle',
            initialRoute: module.initialRoute ?? '/',
            order: module.navigationOrder,
          ));
        }
      }
    }

    destinations.sort((a, b) => a.order.compareTo(b.order));
    return destinations;
  }
}

/// Metadata for a root navigation destination (bottom bar, drawer).
class RootDestination {
  final String moduleId;
  final String label;
  final String iconName;
  final String initialRoute;
  final int order;

  const RootDestination({
    required this.moduleId,
    required this.label,
    required this.iconName,
    required this.initialRoute,
    required this.order,
  });
}
