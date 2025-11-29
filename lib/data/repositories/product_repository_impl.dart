import 'dart:convert';

import 'package:flutter/foundation.dart';
import '../../core/api_client.dart';
import '../../core/result.dart';
import '../../core/strategies/caching_strategy.dart';
import '../../domain/entities/product.dart';
import '../../domain/repositories/product_repository.dart';
import '../../services/local_catalog_storage.dart';

class ProductRepositoryImpl implements ProductRepository {
  ProductRepositoryImpl(this._apiClient, this._cacheContext);

  final ApiClient _apiClient;
  final CacheContext<String> _cacheContext;

  @override
  Future<Result<List<ProductEntity>>> getAll() async {
    final List<ProductEntity> cachedProducts = await _loadProductsFromCache(
      cacheKey: 'products:all',
    );
    if (cachedProducts.isNotEmpty) {
      return Result.success(cachedProducts);
    }

    final Result<dynamic> res = await _apiClient.get('/productos/', auth: true);
    if (res.isFailure) {
      final List<ProductEntity> fallback = await _loadProductsFromLocalIndex();
      if (fallback.isNotEmpty) {
        return Result.success(fallback);
      }
      return Result.failure(res.error!);
    }
    if (res.data is List) {
      final List<Map<String, dynamic>> jsonList = (res.data as List)
          .whereType<Map<String, dynamic>>()
          .toList();
      await _cacheProducts(
        cacheKey: 'products:all',
        productsJson: jsonList,
        expiration: const Duration(minutes: 10),
        mergeIntoIndex: false,
      );
      final List<ProductEntity> items = jsonList
          .map(ProductEntity.fromJson)
          .toList();
      return Result.success(items);
    }
    return Result.failure('Invalid server response');
  }

  @override
  Future<Result<List<ProductEntity>>> getByCategory(int categoryId) async {
    final String categoryKey = 'products:category:$categoryId';

    final List<ProductEntity> cachedCategory = await _loadProductsFromCache(
      cacheKey: categoryKey,
    );
    if (cachedCategory.isNotEmpty) {
      return Result.success(cachedCategory);
    }

    try {
      final Result<dynamic> res = await _apiClient.get(
        '/productos/',
        auth: true,
      );
      if (res.isFailure) return Result.failure(res.error!);
      if (res.data is! List) return Result.failure('Invalid server response');

      final List<dynamic> rawList = res.data as List<dynamic>;
      final List<Map<String, dynamic>> jsonList = rawList
          .whereType<Map<String, dynamic>>()
          .toList();

      final List<Map<String, dynamic>> filteredJson = await compute(
        _filterProductJsonByCategory,
        <String, dynamic>{'list': jsonList, 'categoryId': categoryId},
      );

      await _cacheProducts(
        cacheKey: categoryKey,
        productsJson: filteredJson,
        expiration: const Duration(minutes: 10),
        mergeIntoIndex: false,
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
    bool includeAvailabilityFilter = true,
    int? limit,
  }) async {
    if (name.trim().isEmpty) {
      return Result.failure('Search term cannot be empty');
    }

    final StringBuffer path = StringBuffer('/productos/buscar?nombre=');
    path.write(Uri.encodeQueryComponent(name.trim()));

    if (includeAvailabilityFilter && available != null) {
      path
        ..write('&disponible=')
        ..write(available ? 'true' : 'false');
    }

    if (limit != null) {
      final int resolvedLimit = limit.clamp(1, 100).toInt();
      path
        ..write('&limit=')
        ..write(resolvedLimit);
    }

    Result<dynamic> res;
    try {
      res = await _apiClient.get(path.toString(), auth: false);
    } catch (_) {
      res = Result.failure('Network error');
    }

    if (res.isFailure) {
      final List<ProductEntity> local = await _loadProductsFromLocalIndex();
      if (local.isNotEmpty) {
        final String lower = name.trim().toLowerCase();
        final Iterable<ProductEntity> matches = local.where((
          ProductEntity product,
        ) {
          final bool availabilityMatches = available == null
              ? true
              : product.available == available;
          return availabilityMatches &&
              product.name.toLowerCase().contains(lower);
        });
        final List<ProductEntity> filtered = matches.toList(growable: false);
        if (filtered.isNotEmpty) {
          return Result.success(filtered);
        }
      }
      return Result.failure(res.error!);
    }

    if (res.data is List) {
      final List<Map<String, dynamic>> jsonList = (res.data as List)
          .whereType<Map<String, dynamic>>()
          .toList();
      await _cacheProducts(
        cacheKey: 'products:search:${name.trim().toLowerCase()}',
        productsJson: jsonList,
        expiration: const Duration(minutes: 5),
      );
      final List<ProductEntity> items = jsonList
          .map(ProductEntity.fromJson)
          .toList(growable: false);
      return Result.success(items);
    }

    return Result.failure('Invalid server response');
  }

  Future<void> _cacheProducts({
    required String cacheKey,
    required List<Map<String, dynamic>> productsJson,
    Duration expiration = const Duration(minutes: 10),
    bool mergeIntoIndex = true,
  }) async {
    if (productsJson.isEmpty) return;
    try {
      final String payload = jsonEncode(productsJson);
      await _cacheContext.store(cacheKey, payload, expiration: expiration);
    } catch (_) {}
    if (mergeIntoIndex) {
      try {
        await LocalCatalogStorage.instance.mergeProducts(productsJson);
      } catch (_) {}
    }
  }

  Future<List<ProductEntity>> _loadProductsFromCache({
    required String cacheKey,
    int? categoryId,
  }) async {
    try {
      final CacheResult<String> cached = await _cacheContext.retrieve(cacheKey);
      if (cached.success && cached.data != null && cached.data!.isNotEmpty) {
        final List<Map<String, dynamic>> jsonList = _decodeProductsJson(
          cached.data!,
        );
        if (jsonList.isNotEmpty) {
          final Iterable<Map<String, dynamic>> iterable = categoryId == null
              ? jsonList
              : jsonList.where(
                  (Map<String, dynamic> m) =>
                      ((m['id_tipo'] ?? m['typeId']) as num?)?.toInt() ==
                      categoryId,
                );
          final List<ProductEntity> entities = iterable
              .map(ProductEntity.fromJson)
              .toList(growable: false);
          if (entities.isNotEmpty) {
            return entities;
          }
        }
      }
    } catch (_) {}
    if (categoryId != null) {
      return _loadProductsFromLocalIndex(categoryId: categoryId);
    }
    return _loadProductsFromLocalIndex();
  }

  Future<List<ProductEntity>> _loadProductsFromLocalIndex({
    int? categoryId,
  }) async {
    try {
      final List<Map<String, dynamic>> localProducts = categoryId == null
          ? await LocalCatalogStorage.instance.readAllProducts()
          : await LocalCatalogStorage.instance.readProductsByType(categoryId);
      if (localProducts.isEmpty) return <ProductEntity>[];
      return localProducts.map(ProductEntity.fromJson).toList(growable: false);
    } catch (_) {
      return <ProductEntity>[];
    }
  }

  List<Map<String, dynamic>> _decodeProductsJson(String raw) {
    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.whereType<Map<String, dynamic>>().toList();
      }
    } catch (_) {}
    return <Map<String, dynamic>>[];
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
