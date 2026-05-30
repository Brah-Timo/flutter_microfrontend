/// Simple auth service interface.
abstract class AuthService {
  bool get isAuthenticated;
  String? get currentUserId;
  String? get currentUserEmail;

  Future<void> signIn(String email, String password);
  Future<void> signOut();
}

/// Fake auth service for demo purposes.
class FakeAuthService implements AuthService {
  String? _userId;
  String? _email;

  @override
  bool get isAuthenticated => _userId != null;

  @override
  String? get currentUserId => _userId;

  @override
  String? get currentUserEmail => _email;

  @override
  Future<void> signIn(String email, String password) async {
    await Future.delayed(const Duration(milliseconds: 800));
    if (email.isEmpty || password.length < 4) {
      throw Exception('Invalid credentials');
    }
    _userId = 'user_${email.hashCode}';
    _email = email;
  }

  @override
  Future<void> signOut() async {
    await Future.delayed(const Duration(milliseconds: 200));
    _userId = null;
    _email = null;
  }
}
