import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomeScreen extends StatelessWidget {
  final String? userId;
  final String? email;

  const HomeScreen({super.key, this.userId, this.email});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        backgroundColor: const Color(0xFF5C6BC0),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => context.go('/login'),
            tooltip: 'Sign Out',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome card
            Card(
              color: const Color(0xFF5C6BC0),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.white30,
                      child: Icon(Icons.person, size: 36, color: Colors.white),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome back!',
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 14),
                          ),
                          Text(
                            email ?? 'User',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'ID: ${userId ?? '—'}',
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.6),
                                fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Feature Modules',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // Feature cards
            _FeatureCard(
              icon: Icons.shopping_bag_outlined,
              title: 'Shop',
              subtitle: 'Browse products (lazy loaded)',
              color: const Color(0xFFE91E63),
              onTap: () => context.go('/shop'),
            ),
            const SizedBox(height: 12),
            _FeatureCard(
              icon: Icons.settings_outlined,
              title: 'Settings',
              subtitle: 'App preferences',
              color: const Color(0xFF009688),
              onTap: () => context.go('/settings'),
            ),
            const SizedBox(height: 12),
            _FeatureCard(
              icon: Icons.analytics_outlined,
              title: 'Analytics Dashboard',
              subtitle: 'View app metrics (lazy loaded)',
              color: const Color(0xFF9C27B0),
              onTap: () => context.go('/analytics'),
            ),

            const SizedBox(height: 32),
            const _ArchitectureInfo(),
          ],
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 28),
        ),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle,
            style: const TextStyle(fontSize: 12, color: Colors.grey)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}

class _ArchitectureInfo extends StatelessWidget {
  const _ArchitectureInfo();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.architecture, color: Color(0xFF5C6BC0)),
              SizedBox(width: 8),
              Text(
                'flutter_microfrontend',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF5C6BC0)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'This app uses micro-frontend architecture:',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 6),
          ...[
            '✅ AuthModule — eager (loaded at startup)',
            '✅ HomeModule — eager, root destination',
            '⚡ ShopModule — lazy (loads on first visit)',
            '⚡ SettingsModule — lazy (loads on demand)',
            '⚡ AnalyticsModule — lazy (loads when idle)',
          ].map((text) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(text,
                    style: const TextStyle(fontSize: 11)),
              )),
        ],
      ),
    );
  }
}
