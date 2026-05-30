import 'package:flutter/material.dart';

/// Catches Flutter rendering errors within a module's widget subtree.
///
/// Wrapping a module's root with [ModuleErrorBoundary] prevents errors
/// in one module from bringing down the entire app.
///
/// ```dart
/// GoRoute(
///   path: '/shop',
///   builder: (ctx, state) => ModuleErrorBoundary(
///     moduleId: 'shop',
///     child: const ShopHomePage(),
///     onError: (error, stackTrace) {
///       SentrySDK.captureException(error, stackTrace: stackTrace);
///     },
///   ),
/// )
/// ```
class ModuleErrorBoundary extends StatefulWidget {
  final String moduleId;
  final Widget child;
  final void Function(Object error, StackTrace stackTrace)? onError;
  final Widget Function(Object error, VoidCallback reset)? errorWidget;

  const ModuleErrorBoundary({
    super.key,
    required this.moduleId,
    required this.child,
    this.onError,
    this.errorWidget,
  });

  @override
  State<ModuleErrorBoundary> createState() => _ModuleErrorBoundaryState();
}

class _ModuleErrorBoundaryState extends State<ModuleErrorBoundary> {
  Object? _error;
  StackTrace? _stackTrace;

  void _handleError(Object error, StackTrace stackTrace) {
    setState(() {
      _error = error;
      _stackTrace = stackTrace;
    });
    widget.onError?.call(error, stackTrace);
  }

  void _reset() {
    setState(() {
      _error = null;
      _stackTrace = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return widget.errorWidget?.call(_error!, _reset) ??
          _DefaultModuleErrorWidget(
            moduleId: widget.moduleId,
            error: _error!,
            stackTrace: _stackTrace,
            onReset: _reset,
          );
    }

    return _ErrorCatcher(
      onError: _handleError,
      child: widget.child,
    );
  }
}

/// Internal widget that uses ErrorWidget.builder to catch rendering errors.
class _ErrorCatcher extends StatelessWidget {
  final Widget child;
  final void Function(Object, StackTrace) onError;

  const _ErrorCatcher({required this.child, required this.onError});

  @override
  Widget build(BuildContext context) {
    ErrorWidget.builder = (FlutterErrorDetails details) {
      onError(details.exception, details.stack ?? StackTrace.empty);
      return const SizedBox.shrink();
    };
    return child;
  }
}

// ─── Default Error Widget ─────────────────────────────────────────────────────

class _DefaultModuleErrorWidget extends StatelessWidget {
  const _DefaultModuleErrorWidget({
    required this.moduleId,
    required this.error,
    required this.onReset,
    this.stackTrace,
  });

  final String moduleId;
  final Object error;
  final StackTrace? stackTrace;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) => Material(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  size: 72,
                  color: Color(0xFFFFA726),
                ),
                const SizedBox(height: 20),
                Text(
                  '[$moduleId] Encountered an error',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    error.toString(),
                    style: const TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                    textAlign: TextAlign.left,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      child: const Text('Go Back'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: onReset,
                      icon: const Icon(Icons.refresh,),
                      label: const Text('Try Again'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
}
