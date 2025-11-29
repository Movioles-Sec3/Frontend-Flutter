import '../../core/result.dart';
import '../entities/product.dart';
import '../repositories/product_repository.dart';

class SearchProductsUseCase {
  SearchProductsUseCase(this._repository);

  final ProductRepository _repository;

  Future<Result<List<ProductEntity>>> call({
    required String query,
    bool includeUnavailable = false,
    int? limit,
  }) {
    return _repository.searchByName(
      query,
      available: includeUnavailable ? null : true,
      includeAvailabilityFilter: !includeUnavailable,
      limit: limit,
    );
  }
}
