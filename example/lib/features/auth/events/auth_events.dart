import 'package:flutter_microfrontend/flutter_microfrontend.dart';

/// Emitted when the user successfully signs in.
class UserSignedInEvent extends ModuleEvent {
  final String userId;
  final String email;
  final String displayName;

  UserSignedInEvent({
    required this.userId,
    required this.email,
    required this.displayName,
    required super.sourceModuleId,
  });

  @override
  List<Object?> get props =>
      [...super.props, userId, email, displayName];
}

/// Emitted when the user signs out.
class UserSignedOutEvent extends ModuleEvent {
  final String userId;

  UserSignedOutEvent({
    required this.userId,
    required super.sourceModuleId,
  });

  @override
  List<Object?> get props => [...super.props, userId];
}

/// Emitted when the user's session expires.
class SessionExpiredEvent extends ModuleEvent {
  SessionExpiredEvent({required super.sourceModuleId});
}
