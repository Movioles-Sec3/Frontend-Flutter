import '../../core/result.dart';
import '../entities/product.dart';

abstract class ProductRepository {
  Future<Result<List<ProductEntity>>> getAll();
  Future<Result<List<ProductEntity>>> getByCategory(
    int categoryId, {
    bool forceRefresh = false,
  });
  Future<Result<List<ProductEntity>>> searchByName(
    String name, {
    bool? available,
    bool includeAvailabilityFilter,
    int? limit,
  });
}
