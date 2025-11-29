import '../../core/result.dart';
import '../entities/product.dart';
import '../repositories/product_repository.dart';

class SearchProductsUseCase {
  SearchProductsUseCase(this._repository);

  final ProductRepository _repository;

  Future<Result<List<ProductEntity>>> call(
    String name, {
    bool? available,
    int? limit,
  }) {
    return _repository.searchByName(name, available: available, limit: limit);
  }
}
