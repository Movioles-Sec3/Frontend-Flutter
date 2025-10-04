import '../../core/result.dart';
import '../entities/product.dart';

abstract class ProductRepository {
  Future<Result<List<ProductEntity>>> getAll();
  Future<Result<List<ProductEntity>>> getByCategory(int categoryId);
}
