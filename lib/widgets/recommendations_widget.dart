import 'package:flutter/material.dart';
import '../core/strategies/recommendation_strategy.dart';
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

  List<ProductRecommendation> _recommendations = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _recommendationContext = injector.get<RecommendationContext>();
    _cartService = CartService.instance;
    _loadRecommendations();
  }

  Future<void> _loadRecommendations() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

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
      } else {
        setState(() {
          _error = result.error ?? 'Failed to load recommendations';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error loading recommendations: $e';
        _isLoading = false;
      });
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
        child: Center(
          child: CircularProgressIndicator(),
        ),
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
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
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
              Icon(
                Icons.recommend_outlined,
                size: 48,
                color: Colors.grey,
              ),
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Image
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: Container(
                height: 120,
                width: double.infinity,
                color: Colors.grey[200],
                child: product.imageUrl.isNotEmpty
                    ? Image.network(
                        product.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => const Icon(
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
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
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
                        onPressed: product.available ? () => _addToCart(product) : null,
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

