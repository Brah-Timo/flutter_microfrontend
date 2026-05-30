/// Defines WHEN a [DeferredModule] should be loaded.
enum PreloadStrategy {
  /// Load only when explicitly requested (default — best for most cases).
  onDemand,

  /// Load on the first navigation event pointing to this module's routes.
  onFirstNavigation,

  /// Load automatically after all eager modules finish initializing.
  afterAppReady,

  /// Load after a specified [PreloadConfig.delay].
  afterDelay,

  /// Load when the device appears to be idle (3s after app ready).
  whenIdle,

  /// Load only when a Wi-Fi connection is available.
  onWifiConnection,
}

/// Configuration for preload behavior.
class PreloadConfig {
  /// Delay before loading (used with [PreloadStrategy.afterDelay]).
  final Duration delay;

  /// Number of retry attempts on load failure.
  final int maxRetries;

  /// Delay between retry attempts.
  final Duration retryDelay;

  /// Maximum allowed load time before timeout.
  final Duration loadTimeout;

  /// Whether to cache the loaded module across app restarts.
  /// (Conceptual — actual persistence depends on platform implementation.)
  final bool persistAcrossRestarts;

  const PreloadConfig({
    this.delay = const Duration(seconds: 5),
    this.maxRetries = 3,
    this.retryDelay = const Duration(seconds: 2),
    this.loadTimeout = const Duration(seconds: 30),
    this.persistAcrossRestarts = false,
  });

  /// A sensible default for most modules.
  static const defaults = PreloadConfig();

  /// Aggressive config for critical optional features.
  static const aggressive = PreloadConfig(
    delay: Duration(seconds: 1),
    maxRetries: 5,
    retryDelay: Duration(milliseconds: 500),
    loadTimeout: Duration(seconds: 15),
  );

  /// Conservative config for large/heavy modules.
  static const conservative = PreloadConfig(
    delay: Duration(seconds: 10),
    maxRetries: 2,
    retryDelay: Duration(seconds: 5),
    loadTimeout: Duration(seconds: 60),
  );
}
