import 'strategy.dart';
import '../../domain/entities/product_recommendation.dart';
import '../../domain/usecases/get_recommended_products_usecase.dart';

/// Recommendation request data
class RecommendationRequest {
  RecommendationRequest({
    required this.limit,
    this.categoryId,
    this.userId,
    this.preferences,
  });

  final int limit;
  final int? categoryId;
  final String? userId;
  final Map<String, dynamic>? preferences;
}

/// Recommendation result
class RecommendationResult {
  RecommendationResult({
    required this.success,
    this.products,
    this.error,
    this.strategy,
  });

  final bool success;
  final List<ProductRecommendation>? products;
  final String? error;
  final String? strategy;

  factory RecommendationResult.success(List<ProductRecommendation> products, String strategy) => 
      RecommendationResult(success: true, products: products, strategy: strategy);
  factory RecommendationResult.failure(String error) => 
      RecommendationResult(success: false, error: error);
}

/// Base recommendation strategy interface
abstract class RecommendationStrategy extends Strategy<RecommendationRequest, RecommendationResult> {
  @override
  String get identifier;

  @override
  bool canHandle(RecommendationRequest input) => true;
}

/// Popularity-based recommendation strategy
class PopularityRecommendationStrategy extends RecommendationStrategy {
  PopularityRecommendationStrategy(this._useCase);

  @override
  String get identifier => 'popularity';

  final GetRecommendedProductsUseCase _useCase;

  @override
  Future<RecommendationResult> execute(RecommendationRequest input) async {
    try {
      final result = await _useCase(
        limit: input.limit,
        categoryId: input.categoryId,
      );

      if (result.isSuccess) {
        return RecommendationResult.success(
          result.data!,
          identifier,
        );
      } else {
        return RecommendationResult.failure(result.error ?? 'Failed to get popular products');
      }
    } catch (e) {
      return RecommendationResult.failure('Popularity recommendation failed: $e');
    }
  }
}

/// Category-based recommendation strategy
class CategoryRecommendationStrategy extends RecommendationStrategy {
  CategoryRecommendationStrategy(this._useCase);

  @override
  String get identifier => 'category';

  final GetRecommendedProductsUseCase _useCase;

  @override
  bool canHandle(RecommendationRequest input) {
    return input.categoryId != null;
  }

  @override
  Future<RecommendationResult> execute(RecommendationRequest input) async {
    try {
      if (input.categoryId == null) {
        return RecommendationResult.failure('Category ID is required for category-based recommendations');
      }

      final result = await _useCase(
        limit: input.limit,
        categoryId: input.categoryId,
      );

      if (result.isSuccess) {
        return RecommendationResult.success(
          result.data!,
          identifier,
        );
      } else {
        return RecommendationResult.failure(result.error ?? 'Failed to get category products');
      }
    } catch (e) {
      return RecommendationResult.failure('Category recommendation failed: $e');
    }
  }
}

/// Mixed recommendation strategy (combines multiple strategies)
class MixedRecommendationStrategy extends RecommendationStrategy {
  MixedRecommendationStrategy({
    required this.popularityStrategy,
    required this.categoryStrategy,
  });

  @override
  String get identifier => 'mixed';

  final PopularityRecommendationStrategy popularityStrategy;
  final CategoryRecommendationStrategy categoryStrategy;

  @override
  Future<RecommendationResult> execute(RecommendationRequest input) async {
    try {
      final List<ProductRecommendation> allProducts = [];
      
      // Get popular products (50% of limit)
      final popularityLimit = (input.limit * 0.5).round();
      if (popularityLimit > 0) {
        final popularityRequest = RecommendationRequest(
          limit: popularityLimit,
          categoryId: null,
          userId: input.userId,
          preferences: input.preferences,
        );
        
        final popularityResult = await popularityStrategy.execute(popularityRequest);
        if (popularityResult.success && popularityResult.products != null) {
          allProducts.addAll(popularityResult.products!);
        }
      }

      // Get category products (50% of limit) if category is specified
      if (input.categoryId != null) {
        final categoryLimit = input.limit - allProducts.length;
        if (categoryLimit > 0) {
          final categoryRequest = RecommendationRequest(
            limit: categoryLimit,
            categoryId: input.categoryId,
            userId: input.userId,
            preferences: input.preferences,
          );
          
          final categoryResult = await categoryStrategy.execute(categoryRequest);
          if (categoryResult.success && categoryResult.products != null) {
            allProducts.addAll(categoryResult.products!);
          }
        }
      }

      // Remove duplicates and limit results
      final uniqueProducts = <int, ProductRecommendation>{};
      for (final product in allProducts) {
        uniqueProducts[product.id] = product;
      }

      final finalProducts = uniqueProducts.values.take(input.limit).toList();

      return RecommendationResult.success(finalProducts, identifier);
    } catch (e) {
      return RecommendationResult.failure('Mixed recommendation failed: $e');
    }
  }
}

/// Recommendation context for managing recommendation strategies
class RecommendationContext {
  RecommendationContext({
    required this.defaultStrategy,
    this.strategies = const [],
  });

  final RecommendationStrategy defaultStrategy;
  final List<RecommendationStrategy> strategies;

  /// Get recommendations using the appropriate strategy
  Future<RecommendationResult> getRecommendations(RecommendationRequest request) async {
    final strategy = _selectStrategy(request);
    return await strategy.execute(request);
  }

  /// Select recommendation strategy based on request
  RecommendationStrategy _selectStrategy(RecommendationRequest request) {
    for (final strategy in strategies) {
      if (strategy.canHandle(request)) {
        return strategy;
      }
    }
    return defaultStrategy;
  }

  /// Add a recommendation strategy
  void addStrategy(RecommendationStrategy strategy) {
    strategies.add(strategy);
  }

  /// Get available recommendation strategies
  List<String> getAvailableStrategies() {
    return strategies.map((s) => s.identifier).toList();
  }
}
