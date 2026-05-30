import 'package:flutter_microfrontend/flutter_microfrontend.dart';

/// A configurable mock [MicroModule] for testing.
class MockModule extends MicroModule {
  @override
  final String moduleId;

  @override
  final String moduleName;

  @override
  final List<String> dependencies;

  @override
  final bool isEager;

  @override
  final int loadPriority;

  final void Function()? onRegisterCallback;
  final void Function()? onInitCallback;
  final void Function()? onDisposeCallback;
  final bool shouldThrowOnInit;

  // Tracks how many times each lifecycle was called
  int registerCount = 0;
  int initCount = 0;
  int pauseCount = 0;
  int resumeCount = 0;
  int disposeCount = 0;

  MockModule({
    required this.moduleId,
    String? moduleName,
    this.dependencies = const [],
    this.isEager = false,
    this.loadPriority = 0,
    this.onRegisterCallback,
    this.onInitCallback,
    this.onDisposeCallback,
    this.shouldThrowOnInit = false,
  }) : moduleName = moduleName ?? moduleId;

  @override
  Future<void> onRegister(ModuleInjector injector) async {
    registerCount++;
    onRegisterCallback?.call();
    await super.onRegister(injector);
  }

  @override
  Future<void> onInit() async {
    initCount++;
    if (shouldThrowOnInit) {
      throw Exception('MockModule intentional init failure');
    }
    onInitCallback?.call();
    await super.onInit();
  }

  @override
  Future<void> onPause() async {
    pauseCount++;
    await super.onPause();
  }

  @override
  Future<void> onResume() async {
    resumeCount++;
    await super.onResume();
  }

  @override
  Future<void> onDispose() async {
    disposeCount++;
    onDisposeCallback?.call();
    await super.onDispose();
  }
}
