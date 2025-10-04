import '../entities/product_price_conversion.dart';
import '../../core/result.dart';

abstract class PriceConversionRepository {
  /// Get product with price conversions
  /// 
  /// [productId] - ID of the product to get conversions for
  Future<Result<ProductPriceConversion>> getProductPriceConversion(int productId);
}

