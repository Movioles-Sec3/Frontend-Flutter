import '../../core/result.dart';
import '../entities/product.dart';
import '../repositories/product_repository.dart';

class GetProductsByCategoryUseCase {
  GetProductsByCategoryUseCase(this._repo);

  final ProductRepository _repo;

  Future<Result<List<ProductEntity>>> call(int categoryId) {
    return _repo.getByCategory(categoryId);
  }
}
