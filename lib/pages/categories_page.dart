import 'package:flutter/material.dart';

class CategoriesPage extends StatelessWidget {
  const CategoriesPage({super.key});

  static const List<_Cat> _categories = <_Cat>[
    _Cat(label: 'Drinks', icon: Icons.local_bar_outlined),
    _Cat(label: 'Food', icon: Icons.restaurant_outlined),
    _Cat(label: 'Snacks', icon: Icons.lunch_dining_outlined),
    _Cat(label: 'Desserts', icon: Icons.icecream_outlined),
    _Cat(label: 'Coffee', icon: Icons.local_cafe_outlined),
    _Cat(label: 'Beer', icon: Icons.sports_bar_outlined),
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
              onPressed: () {},
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
  const _Cat({required this.label, required this.icon});
  final String label;
  final IconData icon;
}
