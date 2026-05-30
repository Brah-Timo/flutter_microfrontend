import 'package:flutter/foundation.dart';
import 'package:flutter_microfrontend/flutter_microfrontend.dart';

/// A simple console-based analytics plugin for development.
/// In production, replace with Firebase Analytics, Mixpanel, etc.
class ConsoleAnalyticsPlugin extends AnalyticsPlugin {
  @override
  String get pluginId => 'console_analytics';

  @override
  String get pluginName => 'Console Analytics';

  @override
  bool get initializeBeforeModules => true;

  @override
  int get priority => 50;

  @override
  Future<void> initialize(
    GlobalInjector injector,
    ModuleEventBus eventBus,
  ) async {
    debugPrint('[ConsoleAnalytics] ✅ Initialized');
  }

  @override
  Future<void> trackEvent(
    String eventName, {
    Map<String, dynamic>? parameters,
    String? moduleId,
  }) async {
    debugPrint('[Analytics] 📊 Event: $eventName | module: $moduleId | params: $parameters');
  }

  @override
  Future<void> trackScreen(
    String screenName, {
    String? moduleId,
    Map<String, dynamic>? extra,
  }) async {
    debugPrint('[Analytics] 📺 Screen: $screenName | module: $moduleId');
  }

  @override
  Future<void> setUserId(String userId) async {
    debugPrint('[Analytics] 👤 User ID: $userId');
  }

  @override
  Future<void> setUserProperty(String key, String value) async {
    debugPrint('[Analytics] 🏷️  $key = $value');
  }

  @override
  Future<void> resetUser() async {
    debugPrint('[Analytics] 🔄 User reset');
  }

  @override
  Future<void> onAllModulesReady(List<String> moduleIds) async {
    debugPrint('[Analytics] All modules ready: ${moduleIds.join(', ')}');
  }
}
