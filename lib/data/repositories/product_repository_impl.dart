import '../../core/api_client.dart';
import '../../core/result.dart';
import '../../domain/entities/product.dart';
import '../../domain/repositories/product_repository.dart';

class ProductRepositoryImpl implements ProductRepository {
  ProductRepositoryImpl(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<Result<List<ProductEntity>>> getAll() async {
    final Result<dynamic> res = await _apiClient.get('/productos/', auth: true);
    if (res.isFailure) return Result.failure(res.error!);
    if (res.data is List) {
      final List<ProductEntity> items = (res.data as List)
          .whereType<Map<String, dynamic>>()
          .map(ProductEntity.fromJson)
          .toList();
      return Result.success(items);
    }
    return Result.failure('Invalid server response');
  }

  @override
  Future<Result<List<ProductEntity>>> getByCategory(int categoryId) async {
    final Result<List<ProductEntity>> all = await getAll();
    if (all.isFailure) return Result.failure(all.error!);
    final List<ProductEntity> filtered = all.data!
        .where((ProductEntity p) => p.typeId == categoryId)
        .toList();
    return Result.success(filtered);
  }
}
