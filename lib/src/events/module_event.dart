import 'package:equatable/equatable.dart';

/// The base class for all events in the micro-frontend event system.
///
/// Every event carries:
/// - [sourceModuleId]: which module emitted it
/// - [timestamp]: when it was emitted (auto-assigned)
/// - [eventId]: unique ID for deduplication/tracing
///
/// ## Defining custom events
/// ```dart
/// class UserAuthenticatedEvent extends ModuleEvent {
///   final String userId;
///   final String email;
///
///   const UserAuthenticatedEvent({
///     required this.userId,
///     required this.email,
///     required super.sourceModuleId,
///   });
///
///   @override
///   List<Object?> get props => [...super.props, userId, email];
/// }
/// ```
abstract class ModuleEvent extends Equatable {
  /// ID of the module that emitted this event.
  final String sourceModuleId;

  /// Auto-assigned timestamp of event emission.
  final DateTime timestamp;

  /// Unique event ID (microsecond precision).
  final String eventId;

  ModuleEvent({
    required this.sourceModuleId,
    DateTime? timestamp,
    String? eventId,
  })  : timestamp = timestamp ?? DateTime.now(),
        eventId = eventId ?? _newId();

  static int _counter = 0;
  static String _newId() =>
      '${DateTime.now().microsecondsSinceEpoch}-${++_counter}';

  @override
  List<Object?> get props => [eventId, sourceModuleId, timestamp];

  @override
  String toString() =>
      '${runtimeType}(from: $sourceModuleId, id: $eventId)';
}

// ─── Built-in System Events ──────────────────────────────────────────────────

/// Emitted when a module finishes initialization.
class ModuleReadyEvent extends ModuleEvent {
  final String moduleVersion;

  ModuleReadyEvent({
    required this.moduleVersion,
    required super.sourceModuleId,
  });

  @override
  List<Object?> get props => [...super.props, moduleVersion];
}

/// Emitted when a module is being disposed.
class ModuleDisposedEvent extends ModuleEvent {
  ModuleDisposedEvent({required super.sourceModuleId});
}

/// Emitted when a module encounters a non-fatal error.
class ModuleErrorEvent extends ModuleEvent {
  final Object error;
  final StackTrace stackTrace;
  final bool isFatal;

  ModuleErrorEvent({
    required this.error,
    required this.stackTrace,
    required super.sourceModuleId,
    this.isFatal = false,
  });

  @override
  List<Object?> get props =>
      [...super.props, error.toString(), isFatal];
}

// ─── Common App Events ───────────────────────────────────────────────────────

/// User successfully authenticated.
class UserAuthenticatedEvent extends ModuleEvent {
  final String userId;
  final String email;
  final String displayName;

  UserAuthenticatedEvent({
    required this.userId,
    required this.email,
    required this.displayName,
    required super.sourceModuleId,
  });

  @override
  List<Object?> get props =>
      [...super.props, userId, email, displayName];
}

/// User signed out.
class UserSignedOutEvent extends ModuleEvent {
  final String userId;
  final String reason;

  UserSignedOutEvent({
    required this.userId,
    required super.sourceModuleId,
    this.reason = 'user_action',
  });

  @override
  List<Object?> get props => [...super.props, userId, reason];
}

/// App theme changed.
class ThemeChangedEvent extends ModuleEvent {
  final String themeName;
  final bool isDark;

  ThemeChangedEvent({
    required this.themeName,
    required this.isDark,
    required super.sourceModuleId,
  });

  @override
  List<Object?> get props => [...super.props, themeName, isDark];
}

/// Language/locale changed.
class LocaleChangedEvent extends ModuleEvent {
  final String languageCode;
  final String? countryCode;

  LocaleChangedEvent({
    required this.languageCode,
    this.countryCode,
    required super.sourceModuleId,
  });

  @override
  List<Object?> get props =>
      [...super.props, languageCode, countryCode];
}

/// Network connectivity changed.
class ConnectivityChangedEvent extends ModuleEvent {
  final bool isConnected;
  final String connectionType;

  ConnectivityChangedEvent({
    required this.isConnected,
    required this.connectionType,
    required super.sourceModuleId,
  });

  @override
  List<Object?> get props =>
      [...super.props, isConnected, connectionType];
}
