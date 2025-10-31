import '../entities/product_price_conversion.dart';
import '../repositories/price_conversion_repository.dart';
import '../../core/result.dart';

class GetProductPriceConversionUseCase {
  GetProductPriceConversionUseCase(this._repository);

  final PriceConversionRepository _repository;

  /// Get product with price conversions
  /// 
  /// [productId] - ID of the product to get conversions for
  Future<Result<ProductPriceConversion>> call(int productId) async {
    return await _repository.getProductPriceConversion(productId);
  }
}

