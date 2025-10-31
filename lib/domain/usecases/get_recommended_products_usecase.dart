import '../entities/product_recommendation.dart';
import '../repositories/recommendation_repository.dart';
import '../../core/result.dart';

class GetRecommendedProductsUseCase {
  GetRecommendedProductsUseCase(this._repository);

  final RecommendationRepository _repository;

  /// Get recommended products with optional filters
  /// 
  /// [limit] - Number of products to return (default: 5)
  /// [categoryId] - Optional category filter
  Future<Result<List<ProductRecommendation>>> call({
    int limit = 5,
    int? categoryId,
  }) async {
    return await _repository.getRecommendedProducts(
      limit: limit,
      categoryId: categoryId,
    );
  }
}

