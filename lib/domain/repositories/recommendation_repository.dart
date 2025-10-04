import '../entities/product_recommendation.dart';
import '../../core/result.dart';

abstract class RecommendationRepository {
  /// Get recommended products
  /// 
  /// [limit] - Number of products to return (default: 5)
  /// [categoryId] - Optional category filter
  Future<Result<List<ProductRecommendation>>> getRecommendedProducts({
    int limit = 5,
    int? categoryId,
  });
}

