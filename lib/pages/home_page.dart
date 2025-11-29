import 'package:flutter/material.dart';
import 'categories_page.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/image_cache_manager.dart';
import '../widgets/offline_notice.dart';
import 'products_by_category_page.dart';
import '../widgets/recommendations_widget.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  static const List<Map<String, String>> _promotions = <Map<String, String>>[
    {
      'image':
          'https://images.unsplash.com/photo-1551024601-bec78aea704b?q=80&w=1200&auto=format&fit=crop',
      'title': '2x1 on select beers',
    },
    {
      'image':
          'https://images.unsplash.com/photo-1552566626-52f8b828add9?q=80&w=1200&auto=format&fit=crop',
      'title': 'Karaoke night',
    },
  ];

  static const List<_Category> _categories = <_Category>[
    _Category(id: 1, label: 'Beers', icon: Icons.local_drink_outlined),
    _Category(id: 2, label: 'Cocktails', icon: Icons.wine_bar_outlined),
    _Category(id: 3, label: 'Tapas', icon: Icons.fastfood_outlined),
    _Category(id: 4, label: 'Snacks', icon: Icons.lunch_dining_outlined),
  ];

  static const List<_Venue> _nearbyVenues = <_Venue>[
    _Venue(
      name: 'The Sun Bar',
      subtitle: 'Craft beer, tapas',
      imageUrl:
          'https://images.unsplash.com/photo-1528605248644-14dd04022da1?crop=entropy&cs=tinysrgb&fit=crop&fm=jpg&h=800&w=1200&q=80',
    ),
    _Venue(
      name: 'The Moon',
      subtitle: 'Imported beer, snacks',
      imageUrl:
          'https://images.unsplash.com/photo-1554118811-1e0d58224f24?q=80&w=1200&auto=format&fit=crop',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const OfflineNotice(),
            const SizedBox(height: 16),
            _Promotions(promotions: _promotions),
            const SizedBox(height: 16),
            _HeaderWithSeeAll(
              title: 'Categories',
              onSeeAll: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const CategoriesPage(),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            _CategoriesList(categories: _categories),
            const SizedBox(height: 16),
            const RecommendationsWidget(title: 'Recommended for You', limit: 5),
          ],
        ),
      ),
    );
  }
}

class _Promotions extends StatelessWidget {
  const _Promotions({required this.promotions});

  final List<Map<String, String>> promotions;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 160,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: promotions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (BuildContext context, int index) {
          final Map<String, String> promo = promotions[index];
          return SizedBox(
            width: 260,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl: promo['image']!,
                      cacheKey: 'img:banner:${promo['image']}',
                      cacheManager: AppImageCacheManagers.banners,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      memCacheWidth: 800,
                      memCacheHeight: 400,
                      fadeInDuration: const Duration(milliseconds: 200),
                      placeholderFadeInDuration: const Duration(milliseconds: 100),
                      placeholder: (_, __) => const ColoredBox(
                        color: Color(0xFFE0E0E0),
                        child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                      errorWidget: (_, __, ___) =>
                          const Icon(Icons.broken_image),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  promo['title']!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CategoriesList extends StatelessWidget {
  const _CategoriesList({required this.categories});

  final List<_Category> categories;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 84,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (BuildContext context, int index) {
          final _Category category = categories[index];
          return GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ProductsByCategoryPage(
                    categoryId: category.id,
                    categoryName: category.label,
                  ),
                ),
              );
            },
            child: Column(
              children: <Widget>[
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(category.icon),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: 68,
                  child: Text(
                    category.label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _NearbyList extends StatelessWidget {
  const _NearbyList({required this.venues});

  final List<_Venue> venues;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: venues.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (BuildContext context, int index) {
        final _Venue v = venues[index];
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(v.name, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    v.subtitle,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.grey[700]),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: v.imageUrl,
                cacheKey: 'img:venue:${v.imageUrl}',
                cacheManager: AppImageCacheManagers.productImages,
                width: 120,
                height: 84,
                fit: BoxFit.cover,
                memCacheWidth: 360,
                memCacheHeight: 252,
                fadeInDuration: const Duration(milliseconds: 200),
                placeholderFadeInDuration: const Duration(milliseconds: 100),
                placeholder: (_, __) => const ColoredBox(color: Color(0xFFE0E0E0)),
                errorWidget: (_, __, ___) => const Icon(Icons.broken_image),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
    );
  }
}

class _HeaderWithSeeAll extends StatelessWidget {
  const _HeaderWithSeeAll({required this.title, required this.onSeeAll});

  final String title;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        TextButton.icon(
          onPressed: onSeeAll,
          icon: const Icon(Icons.grid_view_outlined, size: 18),
          label: const Text('See all'),
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.primary,
          ),
        ),
      ],
    );
  }
}

class _Category {
  const _Category({required this.id, required this.label, required this.icon});
  final int id;
  final String label;
  final IconData icon;
}

class _Venue {
  const _Venue({
    required this.name,
    required this.subtitle,
    required this.imageUrl,
  });
  final String name;
  final String subtitle;
  final String imageUrl;
}
