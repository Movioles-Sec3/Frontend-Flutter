import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'categories_page.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/image_cache_manager.dart';
import '../widgets/offline_notice.dart';
import 'products_by_category_page.dart';
import '../widgets/recommendations_widget.dart';
import '../services/cart_service.dart';
import '../domain/usecases/get_products_by_category_usecase.dart';
import '../domain/entities/product.dart';
import '../core/result.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

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
            const _TwoForOneOfferWidget(),
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

/// 2x1 Offer Widget - Shows special 2x1 promotion for product ID 1
class _TwoForOneOfferWidget extends StatefulWidget {
  const _TwoForOneOfferWidget();

  @override
  State<_TwoForOneOfferWidget> createState() => _TwoForOneOfferWidgetState();
}

class _TwoForOneOfferWidgetState extends State<_TwoForOneOfferWidget> {
  ProductEntity? _product;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProduct();
  }

  Future<void> _loadProduct() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Get products from category 1 (Beers) and find product with ID 1
      final GetProductsByCategoryUseCase useCase = GetIt.I.get<GetProductsByCategoryUseCase>();
      final Result<List<ProductEntity>> result = await useCase(1); // Category 1 = Beers

      if (!mounted) return;

      if (result.isSuccess) {
        final List<ProductEntity> products = result.data ?? [];
        // Filter only available products and find product with ID 1
        final List<ProductEntity> availableProducts = products.where((p) => p.available).toList();
        final ProductEntity? product = availableProducts.cast<ProductEntity?>().firstWhere(
          (p) => p?.id == 1,
          orElse: () => null,
        );

        setState(() {
          _product = product ?? (availableProducts.isNotEmpty ? availableProducts.first : null);
          _loading = false;
        });
      } else {
        setState(() {
          _error = 'Could not load offer';
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load offer';
        _loading = false;
      });
    }
  }

  void _addToCart() {
    if (_product == null) return;

    // Add 2 items to cart (2x1 offer)
    CartService.instance.addOrIncrement(
      productId: _product!.id,
      name: _product!.name,
      imageUrl: _product!.imageUrl,
      unitPrice: _product!.price,
    );
    CartService.instance.addOrIncrement(
      productId: _product!.id,
      name: _product!.name,
      imageUrl: _product!.imageUrl,
      unitPrice: _product!.price,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🎉 2x1! Added 2x ${_product!.name} to cart'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        height: 140,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.primaryContainer,
              Theme.of(context).colorScheme.secondaryContainer,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null || _product == null) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.orange.shade700,
            Colors.deepOrange.shade600,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _addToCart,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Product Image
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: _product!.imageUrl,
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                    cacheManager: AppImageCacheManagers.productImages,
                    placeholder: (_, __) => Container(
                      color: Colors.white.withValues(alpha: 0.2),
                      child: const Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      color: Colors.white.withValues(alpha: 0.2),
                      child: const Icon(Icons.local_drink, color: Colors.white, size: 40),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Offer Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '2x1',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange.shade700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'SPECIAL OFFER',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _product!.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Buy 1 Get 1 Free!',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            '\$${_product!.price.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Tap to add',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Arrow Icon
                const Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

