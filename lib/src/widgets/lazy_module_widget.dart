import 'package:flutter/material.dart';
import '../lazy/deferred_module.dart';
import '../contracts/module_contract.dart';

/// A widget that manages loading a [DeferredModule] and displays
/// appropriate UI for each loading state.
///
/// ```dart
/// LazyModuleWidget(
///   module: shopDeferredModule,
///   builder: (context, module) => ShopHomePage(module: module),
///   loading: const ShopSkeletonScreen(),
///   error: (error, retry) => ShopErrorScreen(onRetry: retry),
/// )
/// ```
class LazyModuleWidget extends StatefulWidget {
  final DeferredModule module;
  final Widget Function(BuildContext context, MicroModule module) builder;
  final Widget? loading;
  final Widget Function(Object error, VoidCallback retry)? error;

  /// Whether to start loading immediately on widget mount.
  final bool autoLoad;

  /// Callback fired when the module finishes loading.
  final void Function(MicroModule module)? onLoaded;

  /// Callback fired when loading fails.
  final void Function(Object error)? onError;

  const LazyModuleWidget({
    super.key,
    required this.module,
    required this.builder,
    this.loading,
    this.error,
    this.autoLoad = true,
    this.onLoaded,
    this.onError,
  });

  @override
  State<LazyModuleWidget> createState() => _LazyModuleWidgetState();
}

class _LazyModuleWidgetState extends State<LazyModuleWidget> {
  Future<MicroModule>? _loadFuture;

  @override
  void initState() {
    super.initState();
    if (widget.autoLoad) _startLoad();
  }

  void _startLoad() {
    setState(() {
      _loadFuture = widget.module.load().then((m) {
        widget.onLoaded?.call(m);
        return m;
      }).catchError((Object e) {
        widget.onError?.call(e);
        throw e;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loadFuture == null) return _buildNotStarted();

    return FutureBuilder<MicroModule>(
      future: _loadFuture,
      builder: (context, snapshot) {
        return switch (snapshot.connectionState) {
          ConnectionState.none => _buildNotStarted(),
          ConnectionState.waiting || ConnectionState.active =>
            _buildLoading(),
          ConnectionState.done => snapshot.hasError
              ? _buildError(snapshot.error!, _startLoad)
              : widget.builder(context, snapshot.data!),
        };
      },
    );
  }

  Widget _buildNotStarted() {
    return Center(
      child: ElevatedButton(
        onPressed: _startLoad,
        child: Text('Load ${widget.module.moduleName}'),
      ),
    );
  }

  Widget _buildLoading() {
    return widget.loading ??
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Loading ${widget.module.moduleName}...',
                style: const TextStyle(
                    fontSize: 14, color: Color(0xFF757575)),
              ),
            ],
          ),
        );
  }

  Widget _buildError(Object error, VoidCallback retry) {
    return widget.error?.call(error, retry) ??
        Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off,
                    size: 56, color: Color(0xFFBDBDBD)),
                const SizedBox(height: 16),
                Text(
                  'Failed to load ${widget.module.moduleName}',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  error.toString(),
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF9E9E9E)),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: retry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        );
  }
}
