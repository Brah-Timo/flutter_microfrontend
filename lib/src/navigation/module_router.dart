import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/module_registry.dart';
import '../utils/module_logger.dart';
import 'route_registration.dart';

/// Configuration for [ModuleRouter].
class ModuleRouterConfig {
  /// Initial location when the app starts.
  final String initialLocation;

  /// Global redirect applied before every route change.
  final Future<String?> Function(BuildContext, GoRouterState)? redirect;

  /// Navigation observers (e.g., for analytics).
  final List<NavigatorObserver> observers;

  /// Fallback widget for unknown routes (404).
  final Widget Function(BuildContext, GoRouterState)? errorBuilder;

  /// Whether to enable URL-based navigation on web.
  final bool usePathUrlStrategy;

  const ModuleRouterConfig({
    this.initialLocation = '/',
    this.redirect,
    this.observers = const [],
    this.errorBuilder,
    this.usePathUrlStrategy = true,
  });
}

/// Assembles a [GoRouter] from all routes provided by registered modules.
///
/// The router is rebuilt whenever [rebuild] is called (e.g., after a
/// dynamic module is added).
class ModuleRouter {
  final ModuleRegistry _registry;
  final ModuleRouterConfig? _config;
  final _logger = ModuleLogger('ModuleRouter');
  late GoRouter _goRouter;

  ModuleRouter({
    required ModuleRegistry registry,
    ModuleRouterConfig? config,
  })  : _registry = registry,
        _config = config {
    _build();
  }

  // ─── Public API ────────────────────────────────────────────────────────────

  /// The assembled [GoRouter] ready to be passed to [MaterialApp.router].
  GoRouter get goRouter => _goRouter;

  /// Returns all registered root destinations.
  List<RootDestination> get rootDestinations {
    return _registry.getRootDestinations();
  }

  /// Rebuild the router (call after registering a dynamic module with routes).
  void rebuild() {
    _logger.info('Rebuilding router after dynamic module registration...');
    _build();
  }

  // ─── Internal Build ────────────────────────────────────────────────────────

  void _build() {
    // Collect all routes from RoutableModules via registry
    final routes = _registry.getAllRoutes();

    _logger.info('Building router with ${routes.length} route(s)...');

    _goRouter = GoRouter(
      initialLocation: _config?.initialLocation ?? '/',
      redirect: _config?.redirect,
      observers: _config?.observers ?? const [],
      errorBuilder: _config?.errorBuilder ?? _defaultErrorBuilder,
      routes: [
        ...routes,
        // Catch-all 404
        GoRoute(
          path: '/404',
          builder: (ctx, state) => const _NotFoundPage(),
        ),
      ],
    );
  }

  Widget _defaultErrorBuilder(BuildContext ctx, GoRouterState state) {
    _logger.warning('404: ${state.uri}');
    return const _NotFoundPage();
  }
}

// ─── Default Widgets ─────────────────────────────────────────────────────────

class _NotFoundPage extends StatelessWidget {
  const _NotFoundPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Page Not Found')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off, size: 80, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              '404 — Page Not Found',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'The route you are looking for does not exist.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go('/'),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    );
  }
}
