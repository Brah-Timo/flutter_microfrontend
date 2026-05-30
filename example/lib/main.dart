import 'package:flutter/material.dart';
import 'package:flutter_microfrontend/flutter_microfrontend.dart';

import 'features/auth/auth_module.dart';
import 'features/home/home_module.dart';
import 'features/shop/shop_module.dart';
import 'features/settings/settings_module.dart';
import 'plugins/console_analytics_plugin.dart';

void main() {
  runApp(const MicroFrontendExampleApp());
}

class MicroFrontendExampleApp extends StatelessWidget {
  const MicroFrontendExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MicrofrontendApp(
      title: 'flutter_microfrontend Demo',

      // ─── Modules ───────────────────────────────────────────────────────────
      modules: [
        // ── Eager modules (loaded at startup) ─────────────────────────────
        AuthModule(),    // Priority 100 — first to initialize
        HomeModule(),    // Depends on auth

        // ── Lazy modules (loaded on demand) ────────────────────────────────
        DeferredModule(
          moduleId: 'shop',
          moduleName: 'Shop',
          loader: () async {
            // In a real app with deferred imports:
            // await shop_lib.loadLibrary();
            // return shop_lib.ShopModule();
            await Future.delayed(const Duration(milliseconds: 300));
            return ShopModule();
          },
          preloadStrategy: PreloadStrategy.afterAppReady,
          dependencies: ['auth'],
          config: PreloadConfig(
            maxRetries: 3,
            loadTimeout: const Duration(seconds: 15),
          ),
        ),

        DeferredModule(
          moduleId: 'settings',
          moduleName: 'Settings',
          loader: () async {
            await Future.delayed(const Duration(milliseconds: 100));
            return SettingsModule();
          },
          preloadStrategy: PreloadStrategy.whenIdle,
        ),
      ],

      // ─── Plugins ───────────────────────────────────────────────────────────
      plugins: [
        ConsoleAnalyticsPlugin(),
        // Add more plugins here:
        // SentryPlugin(dsn: '...'),
        // FirebaseAnalyticsPlugin(),
      ],

      // ─── Shared Services ───────────────────────────────────────────────────
      sharedServices: (injector) {
        // Register app-wide services here
        // injector.registerSingleton<HttpClient>(DioClient());
        // injector.registerSingleton<LocalStorage>(HiveStorage());
      },

      // ─── Error Handling ────────────────────────────────────────────────────
      onError: (error, stackTrace) {
        debugPrint('❌ Critical error: $error');
        // In production: Sentry.captureException(error, stackTrace: stackTrace)
      },

      // ─── Theme ─────────────────────────────────────────────────────────────
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF5C6BC0),
        ),
      ),

      // ─── Splash ────────────────────────────────────────────────────────────
      splashWidget: const _SplashScreen(),

      // ─── Error Widget ───────────────────────────────────────────────────────
      errorWidget: (error, retry) => MaterialApp(
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline,
                    size: 64, color: Colors.red),
                const SizedBox(height: 16),
                const Text('App initialization failed',
                    style: TextStyle(fontSize: 18)),
                const SizedBox(height: 8),
                Text(error.toString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 24),
                ElevatedButton(
                    onPressed: retry, child: const Text('Retry')),
              ],
            ),
          ),
        ),
      ),

      // ─── Router Config ─────────────────────────────────────────────────────
      routerConfig: ModuleRouterConfig(
        initialLocation: '/login',
      ),

      debugMode: true,
    );
  }
}

// ─── Splash Screen ────────────────────────────────────────────────────────────

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF5C6BC0),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.widgets_outlined,
                  size: 64,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'flutter_microfrontend',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Bootstrapping modules...',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 32),
              const SizedBox(
                width: 200,
                child: LinearProgressIndicator(
                  backgroundColor: Colors.white24,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
