import 'package:flutter/material.dart';
import 'products_by_category_page.dart';

class CategoriesPage extends StatelessWidget {
  const CategoriesPage({super.key});

  static const List<_Cat> _categories = <_Cat>[
    _Cat(id: 1, label: 'Beers', icon: Icons.local_drink_outlined),
    _Cat(id: 2, label: 'Cocktails', icon: Icons.wine_bar_outlined),
    _Cat(id: 3, label: 'Tapas', icon: Icons.fastfood_outlined),
    _Cat(id: 4, label: 'Snacks', icon: Icons.lunch_dining_outlined),
    _Cat(id: 5, label: 'Desserts', icon: Icons.icecream_outlined),
    _Cat(id: 6, label: 'Coffee', icon: Icons.local_cafe_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Categories')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 2.9,
          ),
          itemCount: _categories.length,
          itemBuilder: (BuildContext context, int index) {
            final _Cat cat = _categories[index];
            return OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ProductsByCategoryPage(
                      categoryId: cat.id,
                      categoryName: cat.label,
                    ),
                  ),
                );
              },
              icon: Icon(cat.icon),
              label: Text(cat.label),
              style: OutlinedButton.styleFrom(
                foregroundColor: colors.onSurface,
                side: BorderSide(color: colors.primary.withValues(alpha: 0.2)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                textStyle: Theme.of(context).textTheme.bodyMedium,
                backgroundColor: colors.surface,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Cat {
  const _Cat({required this.id, required this.label, required this.icon});
  final int id;
  final String label;
  final IconData icon;
}
