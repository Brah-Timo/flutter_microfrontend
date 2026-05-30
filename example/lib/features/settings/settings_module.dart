import 'package:flutter/material.dart';
import 'package:flutter_microfrontend/flutter_microfrontend.dart';
import 'package:go_router/go_router.dart';
import 'screens/settings_screen.dart';

/// Settings module — user preferences, account management.
/// Lazy loaded via DeferredModule wrapper.
class SettingsModule extends MicroModule with RoutableModule {
  @override
  String get moduleId => 'settings';

  @override
  String get moduleName => 'Settings';

  @override
  bool get isRootDestination => true;

  @override
  String? get navigationIconName => 'settings';

  @override
  String? get navigationLabel => 'Settings';

  @override
  int get navigationOrder => 3;

  @override
  Future<void> onInit() async {
    await super.onInit();
    debugPrint('[SettingsModule] ✅ Initialized');
  }

  @override
  List<RouteBase> get routes => [
        GoRoute(
          path: '/settings',
          name: 'settings',
          builder: (ctx, state) => const SettingsScreen(),
        ),
      ];
}
