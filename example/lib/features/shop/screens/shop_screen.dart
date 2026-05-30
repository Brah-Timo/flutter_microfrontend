import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key});

  static final _products = [
    {'id': '1', 'name': 'Wireless Headphones', 'price': '\$79.99', 'emoji': '🎧'},
    {'id': '2', 'name': 'Smart Watch', 'price': '\$199.99', 'emoji': '⌚'},
    {'id': '3', 'name': 'Laptop Stand', 'price': '\$45.00', 'emoji': '💻'},
    {'id': '4', 'name': 'Mechanical Keyboard', 'price': '\$129.00', 'emoji': '⌨️'},
    {'id': '5', 'name': 'USB-C Hub', 'price': '\$35.99', 'emoji': '🔌'},
    {'id': '6', 'name': 'Desk Lamp', 'price': '\$55.00', 'emoji': '💡'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shop'),
        backgroundColor: const Color(0xFFE91E63),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/home'),
        ),
        actions: [
          IconButton(
              icon: const Icon(Icons.shopping_cart_outlined),
              onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: const Color(0xFFE91E63).withOpacity(0.1),
            padding: const EdgeInsets.all(12),
            child: const Row(
              children: [
                Icon(Icons.bolt, color: Color(0xFFE91E63), size: 18),
                SizedBox(width: 8),
                Text(
                  'ShopModule was lazy loaded! 🚀',
                  style: TextStyle(
                      color: Color(0xFFE91E63),
                      fontWeight: FontWeight.w600,
                      fontSize: 13),
                ),
              ],
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.8,
              ),
              itemCount: _products.length,
              itemBuilder: (ctx, i) {
                final p = _products[i];
                return _ProductCard(
                  id: p['id']!,
                  name: p['name']!,
                  price: p['price']!,
                  emoji: p['emoji']!,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final String id, name, price, emoji;
  const _ProductCard(
      {required this.id,
      required this.name,
      required this.price,
      required this.emoji});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.go('/shop/product/$id'),
      child: Card(
        elevation: 3,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 48)),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600),
                maxLines: 2,
              ),
            ),
            const SizedBox(height: 4),
            Text(price,
                style: const TextStyle(
                    color: Color(0xFFE91E63),
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => context.go('/shop/product/$id'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE91E63),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                textStyle: const TextStyle(fontSize: 12),
              ),
              child: const Text('View'),
            ),
          ],
        ),
      ),
    );
  }
}
