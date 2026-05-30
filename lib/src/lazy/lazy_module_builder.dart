import 'package:flutter/material.dart';
import '../contracts/module_contract.dart';
import 'deferred_module.dart';
import 'preload_strategy.dart';

/// A builder-pattern helper for constructing [DeferredModule]s fluently.
///
/// ```dart
/// final shopModule = LazyModuleBuilder('shop')
///   .withName('Shop')
///   .withLoader(() async => ShopModule())
///   .withDependencies(['auth', 'core'])
///   .withStrategy(PreloadStrategy.afterAppReady)
///   .withRoutePrefixes(['/shop'])
///   .build();
/// ```
class LazyModuleBuilder {
  final String _moduleId;
  String? _moduleName;
  Future<MicroModule> Function()? _loader;
  List<String> _dependencies = const [];
  List<String> _routePrefixes = const [];
  PreloadStrategy _strategy = PreloadStrategy.onDemand;
  PreloadConfig? _config;

  LazyModuleBuilder(this._moduleId);

  LazyModuleBuilder withName(String name) {
    _moduleName = name;
    return this;
  }

  LazyModuleBuilder withLoader(Future<MicroModule> Function() loader) {
    _loader = loader;
    return this;
  }

  LazyModuleBuilder withDependencies(List<String> deps) {
    _dependencies = deps;
    return this;
  }

  LazyModuleBuilder withRoutePrefixes(List<String> prefixes) {
    _routePrefixes = prefixes;
    return this;
  }

  LazyModuleBuilder withStrategy(PreloadStrategy strategy) {
    _strategy = strategy;
    return this;
  }

  LazyModuleBuilder withConfig(PreloadConfig config) {
    _config = config;
    return this;
  }

  /// Build and return the [DeferredModule].
  DeferredModule build() {
    assert(_loader != null, 'LazyModuleBuilder: loader must be set via withLoader().');
    return DeferredModule(
      moduleId: _moduleId,
      moduleName: _moduleName ?? _moduleId,
      loader: _loader!,
      dependencies: _dependencies,
      routePrefixes: _routePrefixes,
      preloadStrategy: _strategy,
      config: _config,
    );
  }
}

// ─── Convenience factory ──────────────────────────────────────────────────────

extension DeferredModuleX on DeferredModule {
  /// Wraps a loaded module's widget in a [FutureBuilder] that handles
  /// loading/error/ready states.
  Widget buildWidget({
    required Widget Function(BuildContext, MicroModule) onReady,
    Widget? loading,
    Widget Function(Object error, VoidCallback retry)? onError,
  }) {
    return _DeferredModuleShell(
      module: this,
      onReady: onReady,
      loading: loading,
      onError: onError,
    );
  }
}

class _DeferredModuleShell extends StatefulWidget {
  final DeferredModule module;
  final Widget Function(BuildContext, MicroModule) onReady;
  final Widget? loading;
  final Widget Function(Object error, VoidCallback retry)? onError;

  const _DeferredModuleShell({
    required this.module,
    required this.onReady,
    this.loading,
    this.onError,
  });

  @override
  State<_DeferredModuleShell> createState() => _DeferredModuleShellState();
}

class _DeferredModuleShellState extends State<_DeferredModuleShell> {
  late Future<MicroModule> _loadFuture;

  @override
  void initState() {
    super.initState();
    _loadFuture = widget.module.load();
  }

  void _retry() => setState(() => _loadFuture = widget.module.load());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<MicroModule>(
      future: _loadFuture,
      builder: (ctx, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return widget.loading ??
              const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return widget.onError?.call(snap.error!, _retry) ??
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error, color: Colors.red, size: 48),
                    const SizedBox(height: 12),
                    Text('Failed to load ${widget.module.moduleName}'),
                    TextButton(
                        onPressed: _retry, child: const Text('Retry')),
                  ],
                ),
              );
        }
        return widget.onReady(ctx, snap.data!);
      },
    );
  }
}
