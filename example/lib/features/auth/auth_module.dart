import 'package:flutter_microfrontend/flutter_microfrontend.dart';
import 'package:go_router/go_router.dart';
import 'events/auth_events.dart';
import 'screens/login_screen.dart';
import 'services/auth_service.dart';

/// Authentication module — handles sign-in, sign-out, session management.
///
/// Publishes:
/// - [UserSignedInEvent]
/// - [UserSignedOutEvent]
/// - [SessionExpiredEvent]
class AuthModule extends MicroModule
    with RoutableModule, EventAwareModule, ServiceModule {
  @override
  String get moduleId => 'auth';

  @override
  String get moduleName => 'Authentication';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'User authentication & session management';

  @override
  bool get isEager => true;

  @override
  int get loadPriority => 100;

  @override
  List<Type> get publishedEvents => [
        UserSignedInEvent,
        UserSignedOutEvent,
        SessionExpiredEvent,
      ];

  @override
  List<Type> get exposedServices => [AuthService];

  // ─── DI ───────────────────────────────────────────────────────────────────

  late ModuleInjector _injector;

  @override
  Future<void> onRegister(ModuleInjector injector) async {
    _injector = injector;
    // Register locally + expose globally so other modules can check auth state
    injector.exposeGlobally<AuthService>(() => FakeAuthService());
    await super.onRegister(injector);
  }

  // ─── Routes ───────────────────────────────────────────────────────────────

  @override
  List<RouteBase> get routes => [
        GoRoute(
          path: '/login',
          name: 'login',
          builder: (ctx, state) => LoginScreen(
            authService: _injector.get<AuthService>(),
            onSuccess: (userId, email) {
              emit(UserSignedInEvent(
                userId: userId,
                email: email,
                displayName: email.split('@').first,
                sourceModuleId: moduleId,
              ));
            },
          ),
        ),
      ];

  @override
  String get initialRoute => '/login';

  // ─── Public API ───────────────────────────────────────────────────────────

  bool get isAuthenticated =>
      _injector.get<AuthService>().isAuthenticated;

  Future<void> signOut() async {
    final service = _injector.get<AuthService>();
    final userId = service.currentUserId ?? '';
    await service.signOut();
    emit(UserSignedOutEvent(
      userId: userId,
      sourceModuleId: moduleId,
    ));
  }
}
