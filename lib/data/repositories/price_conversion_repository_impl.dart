import '../../core/api_client.dart';
import '../../core/result.dart';
import '../../domain/entities/product_price_conversion.dart';
import '../../domain/repositories/price_conversion_repository.dart';

class PriceConversionRepositoryImpl implements PriceConversionRepository {
  PriceConversionRepositoryImpl(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<Result<ProductPriceConversion>> getProductPriceConversion(int productId) async {
    try {
      final path = '/productos/$productId/conversiones';
      final result = await _apiClient.get(path);

      if (result.isSuccess) {
        final data = result.data as Map<String, dynamic>;
        final priceConversion = ProductPriceConversion.fromJson(data);
        return Result.success(priceConversion);
      } else {
        return Result.failure(result.error ?? 'Failed to fetch price conversions');
      }
    } catch (e) {
      return Result.failure('Error fetching price conversions: $e');
    }
  }
}

