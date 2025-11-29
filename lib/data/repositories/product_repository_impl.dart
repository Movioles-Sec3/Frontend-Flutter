import 'package:flutter/foundation.dart';
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
    try {
      // Fetch raw list to allow isolate processing
      final Result<dynamic> res = await _apiClient.get(
        '/productos/',
        auth: true,
      );
      if (res.isFailure) return Result.failure(res.error!);
      if (res.data is! List) return Result.failure('Invalid server response');

      // Use background isolate to filter by category on large datasets
      final List<dynamic> rawList = res.data as List<dynamic>;
      final List<Map<String, dynamic>> filteredJson = await compute(
        _filterProductJsonByCategory,
        <String, dynamic>{'list': rawList, 'categoryId': categoryId},
      );

      final List<ProductEntity> filtered = filteredJson
          .map(ProductEntity.fromJson)
          .toList(growable: false);

      return Result.success(filtered);
    } catch (e) {
      return Result.failure('Unable to filter products: $e');
    }
  }

  @override
  Future<Result<List<ProductEntity>>> searchByName(
    String name, {
    bool? available,
    int? limit,
  }) async {
    if (name.trim().isEmpty) {
      return Result.failure('Search term cannot be empty');
    }

    final StringBuffer path = StringBuffer('/productos/buscar?nombre=');
    path.write(Uri.encodeQueryComponent(name.trim()));

    if (available != null) {
      path
        ..write('&disponible=')
        ..write(available.toString());
    }

    if (limit != null) {
      final int resolvedLimit = limit.clamp(1, 100).toInt();
      path
        ..write('&limit=')
        ..write(resolvedLimit);
    }

    final Result<dynamic> res = await _apiClient.get(
      path.toString(),
      auth: false,
    );

    if (res.isFailure) return Result.failure(res.error!);

    if (res.data is List) {
      final List<ProductEntity> items = (res.data as List)
          .whereType<Map<String, dynamic>>()
          .map(ProductEntity.fromJson)
          .toList(growable: false);
      return Result.success(items);
    }

    return Result.failure('Invalid server response');
  }
}

/// Top-level function for compute to run in an isolate
List<Map<String, dynamic>> _filterProductJsonByCategory(
  Map<String, dynamic> args,
) {
  final List<dynamic> list = args['list'] as List<dynamic>? ?? <dynamic>[];
  final int categoryId = (args['categoryId'] as num?)?.toInt() ?? -1;

  if (categoryId <= 0) return <Map<String, dynamic>>[];

  final Iterable<Map<String, dynamic>> maps = list
      .whereType<Map<String, dynamic>>();
  final List<Map<String, dynamic>> filtered = maps
      .where(
        (Map<String, dynamic> m) =>
            ((m['id_tipo'] as num?)?.toInt() ?? -1) == categoryId,
      )
      .toList(growable: false);
  return filtered;
}
