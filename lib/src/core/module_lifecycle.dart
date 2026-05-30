import '../contracts/module_contract.dart';

/// Tracks and manages the lifecycle state of a single [MicroModule].
///
/// Each registered module has one [ModuleLifecycleManager] that transitions
/// through states:
/// `registered → initializing → ready → paused → disposing → disposed`
class ModuleLifecycleManager {
  ModuleLifecycleState _state = ModuleLifecycleState.registered;
  DateTime? _registeredAt;
  DateTime? _readyAt;
  DateTime? _disposedAt;
  Object? _lastError;
  StackTrace? _lastErrorStackTrace;
  int _pauseCount = 0;
  int _resumeCount = 0;

  final String moduleId;

  ModuleLifecycleManager(this.moduleId) {
    _registeredAt = DateTime.now();
  }

  // ─── State Access ──────────────────────────────────────────────────────────

  ModuleLifecycleState get state => _state;
  bool get isReady => _state == ModuleLifecycleState.ready;
  bool get isPaused => _state == ModuleLifecycleState.paused;
  bool get isDisposed => _state == ModuleLifecycleState.disposed;
  bool get hasError => _state == ModuleLifecycleState.error;
  Object? get lastError => _lastError;

  // ─── Transitions ───────────────────────────────────────────────────────────

  bool transitionTo(ModuleLifecycleState newState, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (!_isValidTransition(_state, newState)) {
      return false;
    }
    _state = newState;
    if (newState == ModuleLifecycleState.ready) _readyAt = DateTime.now();
    if (newState == ModuleLifecycleState.disposed) _disposedAt = DateTime.now();
    if (newState == ModuleLifecycleState.paused) _pauseCount++;
    if (newState == ModuleLifecycleState.ready && _pauseCount > 0) _resumeCount++;
    if (error != null) {
      _lastError = error;
      _lastErrorStackTrace = stackTrace;
    }
    return true;
  }

  // ─── Diagnostics ───────────────────────────────────────────────────────────

  ModuleLifecycleDiagnostics get diagnostics => ModuleLifecycleDiagnostics(
        moduleId: moduleId,
        currentState: _state,
        registeredAt: _registeredAt,
        readyAt: _readyAt,
        disposedAt: _disposedAt,
        pauseCount: _pauseCount,
        resumeCount: _resumeCount,
        lastError: _lastError,
        lastErrorStackTrace: _lastErrorStackTrace,
      );

  // ─── Valid Transitions ─────────────────────────────────────────────────────

  static bool _isValidTransition(
    ModuleLifecycleState from,
    ModuleLifecycleState to,
  ) {
    const transitions = <ModuleLifecycleState, Set<ModuleLifecycleState>>{
      ModuleLifecycleState.registered: {
        ModuleLifecycleState.initializing,
        ModuleLifecycleState.error,
      },
      ModuleLifecycleState.initializing: {
        ModuleLifecycleState.ready,
        ModuleLifecycleState.error,
      },
      ModuleLifecycleState.ready: {
        ModuleLifecycleState.paused,
        ModuleLifecycleState.disposing,
        ModuleLifecycleState.error,
      },
      ModuleLifecycleState.paused: {
        ModuleLifecycleState.ready,
        ModuleLifecycleState.disposing,
        ModuleLifecycleState.error,
      },
      ModuleLifecycleState.disposing: {
        ModuleLifecycleState.disposed,
        ModuleLifecycleState.error,
      },
      ModuleLifecycleState.error: {
        ModuleLifecycleState.disposing,
        ModuleLifecycleState.disposed,
      },
    };
    return transitions[from]?.contains(to) ?? false;
  }
}

// ─── Diagnostics ─────────────────────────────────────────────────────────────

/// Snapshot of a module's lifecycle diagnostics at a point in time.
class ModuleLifecycleDiagnostics {
  final String moduleId;
  final ModuleLifecycleState currentState;
  final DateTime? registeredAt;
  final DateTime? readyAt;
  final DateTime? disposedAt;
  final int pauseCount;
  final int resumeCount;
  final Object? lastError;
  final StackTrace? lastErrorStackTrace;

  /// Time from registration to ready, or null if not yet ready.
  Duration? get initializationTime {
    if (registeredAt == null || readyAt == null) return null;
    return readyAt!.difference(registeredAt!);
  }

  const ModuleLifecycleDiagnostics({
    required this.moduleId,
    required this.currentState,
    this.registeredAt,
    this.readyAt,
    this.disposedAt,
    required this.pauseCount,
    required this.resumeCount,
    this.lastError,
    this.lastErrorStackTrace,
  });

  @override
  String toString() => 'Diagnostics($moduleId: $currentState, '
      'initTime: ${initializationTime?.inMilliseconds}ms, '
      'pauses: $pauseCount)';
}
