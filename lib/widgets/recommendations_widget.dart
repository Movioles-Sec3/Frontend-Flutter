import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../core/strategies/recommendation_strategy.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/image_cache_manager.dart';
import '../services/local_catalog_storage.dart';
import '../core/strategies/error_handling_strategy.dart';
import '../domain/entities/product_recommendation.dart';
import '../di/injector.dart';
import '../services/cart_service.dart';

class RecommendationsWidget extends StatefulWidget {
  const RecommendationsWidget({
    super.key,
    this.title = 'Recommended Products',
    this.limit = 5,
    this.categoryId,
    this.showTitle = true,
  });

  final String title;
  final int limit;
  final int? categoryId;
  final bool showTitle;

  @override
  State<RecommendationsWidget> createState() => _RecommendationsWidgetState();
}

class _RecommendationsWidgetState extends State<RecommendationsWidget> {
  late final RecommendationContext _recommendationContext;
  late final CartService _cartService;
  late final ErrorHandlingContext _errorHandlingContext;

  List<ProductRecommendation> _recommendations = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _recommendationContext = injector.get<RecommendationContext>();
    _cartService = CartService.instance;
    _errorHandlingContext = injector.get<ErrorHandlingContext>();
    _loadRecommendations();
  }

  Future<void> _loadRecommendations() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    // Fast path: try cached recommendations first
    try {
      final List<Map<String, dynamic>> cached = widget.categoryId == null
          ? await LocalCatalogStorage.instance.readHomeRecommended()
          : await LocalCatalogStorage.instance.readCategoryRecommended(
              categoryId: widget.categoryId!,
            );
      if (cached.isNotEmpty && mounted) {
        final list = cached
            .map((m) {
              final ProductType pt = ProductType.fromJson(
                (m['productType'] as Map<String, dynamic>?) ??
                    <String, dynamic>{
                      'id': (m['productTypeId'] ?? m['id_tipo'] ?? 0),
                      'nombre': (m['productTypeName'] ?? ''),
                    },
              );
              return ProductRecommendation(
                id: (m['id'] as num?)?.toInt() ?? 0,
                name: (m['name'] ?? m['nombre'] ?? '').toString(),
                description: (m['description'] ?? m['descripcion'] ?? '')
                    .toString(),
                imageUrl:
                    (m['imageUrl'] ?? m['imagen_url'] ?? m['imagen'] ?? '')
                        .toString(),
                price: ((m['price'] ?? m['precio'] ?? 0) as num).toDouble(),
                available: (m['available'] ?? m['disponible'] ?? true) as bool,
                typeId:
                    (m['productTypeId'] as num?)?.toInt() ??
                    (m['id_tipo'] as num?)?.toInt() ??
                    pt.id,
                productType: pt,
              );
            })
            .toList(growable: false);
        setState(() {
          _recommendations = list;
          _isLoading = false;
        });
      }
    } catch (_) {}

    try {
      final request = RecommendationRequest(
        limit: widget.limit,
        categoryId: widget.categoryId,
      );

      final result = await _recommendationContext.getRecommendations(request);

      if (result.success && result.products != null) {
        setState(() {
          _recommendations = result.products!;
          _isLoading = false;
        });

        // Persist recommendations to cache for offline access
        try {
          final raw = _recommendations
              .map(
                (p) => <String, dynamic>{
                  'id': p.id,
                  'name': p.name,
                  'description': p.description,
                  'imageUrl': p.imageUrl,
                  'price': p.price,
                  'available': p.available,
                  'productTypeId': p.productType.id,
                  'productType': p.productType.toJson(),
                },
              )
              .toList(growable: false);
          if (widget.categoryId == null) {
            // ignore: discarded_futures
            LocalCatalogStorage.instance.saveHomeRecommended(raw);
          } else {
            // ignore: discarded_futures
            LocalCatalogStorage.instance.saveCategoryRecommended(
              categoryId: widget.categoryId!,
              products: raw,
            );
          }
        } catch (_) {}
      } else {
        final message = result.error;
        String friendly = 'Failed to load recommendations';
        if (message != null && message.isNotEmpty) {
          try {
            final handled = await _errorHandlingContext.handleError(
              Exception(message),
            );
            friendly = handled.userMessage;
          } catch (_) {}
        }
        if (mounted) {
          setState(() {
            // Only surface error if we have nothing to show
            if (_recommendations.isEmpty) {
              _error = friendly;
            }
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      String friendly = 'Error loading recommendations';
      try {
        final handled = await _errorHandlingContext.handleError(
          e is Exception ? e : Exception(e.toString()),
        );
        friendly = handled.userMessage;
      } catch (_) {}
      if (mounted) {
        setState(() {
          if (_recommendations.isEmpty) {
            _error = friendly;
          }
          _isLoading = false;
        });
      }
    }
  }

  void _addToCart(ProductRecommendation product) {
    _cartService.addOrIncrement(
      productId: product.id,
      name: product.name,
      imageUrl: product.imageUrl,
      unitPrice: product.price,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${product.name} added to cart'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.showTitle) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_error != null)
                  IconButton(
                    onPressed: _loadRecommendations,
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Retry',
                  ),
              ],
            ),
          ),
          _buildRecommendationsList(),
        ],
      );
    }

    return _buildRecommendationsList();
  }

  Widget _buildRecommendationsList() {
    if (_isLoading) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Container(
        height: 200,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _loadRecommendations,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_recommendations.isEmpty) {
      return Container(
        height: 200,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.recommend_outlined, size: 48, color: Colors.grey),
              SizedBox(height: 8),
              Text(
                'No recommendations available',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: 280,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _recommendations.length,
        itemBuilder: (context, index) {
          final product = _recommendations[index];
          return _buildProductCard(product);
        },
      ),
    );
  }

  Widget _buildProductCard(ProductRecommendation product) {
    return Container(
      width: 200,
      margin: const EdgeInsets.only(right: 12),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Image
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
              child: Container(
                height: 120,
                width: double.infinity,
                color: Colors.grey[200],
                child: product.imageUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: product.imageUrl,
                        cacheKey: 'img:reco:${product.id}:${product.imageUrl}',
                        cacheManager: AppImageCacheManagers.productImages,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => const SizedBox.shrink(),
                        errorWidget: (_, __, ___) => const Icon(
                          Icons.image_not_supported,
                          size: 48,
                          color: Colors.grey,
                        ),
                      )
                    : const Icon(
                        Icons.image_not_supported,
                        size: 48,
                        color: Colors.grey,
                      ),
              ),
            ),

            // Product Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product Type Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        product.productType.name,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Product Name
                    Text(
                      product.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 4),

                    // Price
                    Text(
                      '\$${product.price.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),

                    const Spacer(),

                    // Add to Cart Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: product.available
                            ? () => _addToCart(product)
                            : null,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          product.available ? 'Add to Cart' : 'Unavailable',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
