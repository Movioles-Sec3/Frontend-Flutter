import '../../core/api_client.dart';
import '../../core/result.dart';
import '../../domain/entities/product_recommendation.dart';
import '../../domain/repositories/recommendation_repository.dart';

class RecommendationRepositoryImpl implements RecommendationRepository {
  RecommendationRepositoryImpl(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<Result<List<ProductRecommendation>>> getRecommendedProducts({
    int limit = 5,
    int? categoryId,
  }) async {
    try {
      // Build query parameters
      final queryParams = <String, String>{
        'limit': limit.toString(),
      };
      
      if (categoryId != null) {
        queryParams['categoria_id'] = categoryId.toString();
      }

      // Build URL with query parameters
      final queryString = queryParams.entries
          .map((e) => '${e.key}=${e.value}')
          .join('&');
      final path = '/productos/recomendados?$queryString';

      final result = await _apiClient.get(path);

      if (result.isSuccess) {
        final data = result.data as List<dynamic>;
        final recommendations = data
            .map((json) => ProductRecommendation.fromJson(json as Map<String, dynamic>))
            .toList();

        return Result.success(recommendations);
      } else {
        return Result.failure(result.error ?? 'Failed to fetch recommendations');
      }
    } catch (e) {
      return Result.failure('Error fetching recommendations: $e');
    }
  }
}

