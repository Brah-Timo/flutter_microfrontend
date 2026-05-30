import 'package:flutter/material.dart';
import 'package:flutter_microfrontend/flutter_microfrontend.dart';
import 'package:go_router/go_router.dart';
import '../auth/events/auth_events.dart';
import 'screens/home_screen.dart';

/// Home module — the main dashboard of the app.
class HomeModule extends MicroModule
    with RoutableModule, EventAwareModule {
  @override
  String get moduleId => 'home';

  @override
  String get moduleName => 'Home';

  @override
  List<String> get dependencies => ['auth'];

  @override
  bool get isEager => true;

  @override
  bool get isRootDestination => true;

  @override
  String? get navigationIconName => 'home';

  @override
  String? get navigationLabel => 'Home';

  @override
  int get navigationOrder => 1;

  @override
  List<Type> get subscribedEvents => [UserSignedInEvent, UserSignedOutEvent];

  // User state tracked via events
  String? _currentUserId;
  String? _currentEmail;

  @override
  Future<void> onInit() async {
    await super.onInit();

    listen<UserSignedInEvent>((event) {
      _currentUserId = event.userId;
      _currentEmail = event.email;
    });

    listen<UserSignedOutEvent>((event) {
      _currentUserId = null;
      _currentEmail = null;
    });
  }

  @override
  List<RouteBase> get routes => [
        GoRoute(
          path: '/home',
          name: 'home',
          builder: (ctx, state) => HomeScreen(
            userId: _currentUserId,
            email: _currentEmail,
          ),
        ),
      ];

  @override
  String get initialRoute => '/home';
}
