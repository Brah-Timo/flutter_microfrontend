import 'module_contract.dart';
import '../injection/module_injector.dart';

/// Mixin for modules that expose shared services to other modules.
///
/// While every module can register services internally, a [ServiceModule]
/// explicitly declares which services it makes publicly available to the
/// broader system through the [GlobalInjector].
///
/// ## Example
/// ```dart
/// class CoreModule extends MicroModule with ServiceModule {
///   @override String get moduleId => 'core';
///   @override String get moduleName => 'Core Services';
///   @override bool get isEager => true;
///
///   @override
///   List<Type> get exposedServices => [HttpClient, LocalStorage, TokenManager];
///
///   @override
///   Future<void> onRegister(ModuleInjector injector) async {
///     // Register to global injector so all modules can access these
///     injector.registerGlobalSingleton<HttpClient>(
///       () => DioHttpClient(baseUrl: Env.apiUrl),
///     );
///   }
/// }
/// ```
mixin ServiceModule on MicroModule {
  /// Types of services this module exposes to the global DI container.
  ///
  /// This is purely declarative/documentation — it helps teams understand
  /// the public API of this module without reading its implementation.
  List<Type> get exposedServices => const [];

  /// Register services that should be accessible globally.
  ///
  /// Called automatically by [ModuleRegistry] after [onRegister].
  Future<void> registerGlobalServices(ModuleInjector injector) async {}

  /// Whether this module's global services should be registered
  /// before other modules' local registrations.
  bool get registerGlobalServicesFirst => true;
}
