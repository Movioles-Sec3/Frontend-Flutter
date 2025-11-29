import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';

class _Keys {
  // Home
  static const String homeFeed = 'home:feed:v1';
  static const String homeLayout = 'home:layout:v1';
  static const String homeRecommended = 'home:recommended:v1';
  static const String productsIndex = 'products:index:v1';

  // Categories
  static const String categoriesList = 'categories:list:v1';
  static String categoryPage(int categoryId, int page) =>
      'category:$categoryId:products:page:$page:v1';
  static String categoryRecommended(int categoryId) =>
      'category:$categoryId:recommended:v1';
}

/// Local storage for catalog data (home feed, categories, products per category)
class LocalCatalogStorage {
  LocalCatalogStorage._();
  static final LocalCatalogStorage instance = LocalCatalogStorage._();

  static const String _boxName = 'catalog';

  Future<Box<String>> _box() async {
    if (!Hive.isBoxOpen(_boxName)) {
      await Hive.openBox<String>(_boxName);
    }
    return Hive.box<String>(_boxName);
  }

  Future<void> _put(String key, String data, Duration ttl) async {
    final box = await _box();
    final int expiresAt = DateTime.now().add(ttl).millisecondsSinceEpoch;
    final String envelope = jsonEncode(<String, dynamic>{
      'data': data,
      'exp': expiresAt,
    });
    await box.put(key, envelope);
  }

  Future<String?> _get(String key) async {
    final box = await _box();
    final String? envelope = box.get(key);
    if (envelope == null || envelope.isEmpty) return null;
    try {
      final Map<String, dynamic> m =
          jsonDecode(envelope) as Map<String, dynamic>;
      final int exp = (m['exp'] ?? 0) as int;
      if (exp > 0 && DateTime.now().millisecondsSinceEpoch > exp) {
        await box.delete(key);
        return null;
      }
      final String data = (m['data'] ?? '') as String;
      return data.isEmpty ? null : data;
    } catch (_) {
      return null;
    }
  }

  // Home feed/layout
  Future<void> saveHomeFeed(Map<String, dynamic> feed) async {
    await _put(_Keys.homeFeed, jsonEncode(feed), const Duration(minutes: 30));
  }

  Future<Map<String, dynamic>?> readHomeFeed() async {
    final String? raw = await _get(_Keys.homeFeed);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveHomeLayout(Map<String, dynamic> layout) async {
    await _put(
      _Keys.homeLayout,
      jsonEncode(layout),
      const Duration(minutes: 30),
    );
  }

  Future<Map<String, dynamic>?> readHomeLayout() async {
    final String? raw = await _get(_Keys.homeLayout);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  // Categories list
  Future<void> saveCategoriesList(List<Map<String, dynamic>> categories) async {
    await _put(
      _Keys.categoriesList,
      jsonEncode(categories),
      const Duration(minutes: 30),
    );
  }

  Future<List<Map<String, dynamic>>> readCategoriesList() async {
    final String? raw = await _get(_Keys.categoriesList);
    if (raw == null) return <Map<String, dynamic>>[];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded.cast<Map<String, dynamic>>();
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  // Products by category page
  Future<void> saveCategoryPage({
    required int categoryId,
    required int page,
    required List<Map<String, dynamic>> products,
    Duration ttl = const Duration(minutes: 10),
  }) async {
    final List<Map<String, dynamic>> normalized = _normalizeProductsList(
      products,
    );
    await _put(
      _Keys.categoryPage(categoryId, page),
      jsonEncode(normalized),
      ttl,
    );
  }

  Future<List<Map<String, dynamic>>> readCategoryPage({
    required int categoryId,
    required int page,
  }) async {
    final String? raw = await _get(_Keys.categoryPage(categoryId, page));
    if (raw == null) return <Map<String, dynamic>>[];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded.cast<Map<String, dynamic>>();
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  // Recommendations (generic)
  Future<void> saveHomeRecommended(List<Map<String, dynamic>> products) async {
    final List<Map<String, dynamic>> normalized = _normalizeProductsList(
      products,
    );
    await _put(
      _Keys.homeRecommended,
      jsonEncode(normalized),
      const Duration(minutes: 30),
    );
    await mergeProducts(normalized);
  }

  Future<List<Map<String, dynamic>>> readHomeRecommended() async {
    final String? raw = await _get(_Keys.homeRecommended);
    if (raw == null) return <Map<String, dynamic>>[];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded.cast<Map<String, dynamic>>();
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  // Recommendations by category
  Future<void> saveCategoryRecommended({
    required int categoryId,
    required List<Map<String, dynamic>> products,
  }) async {
    final List<Map<String, dynamic>> normalized = _normalizeProductsList(
      products,
    );
    await _put(
      _Keys.categoryRecommended(categoryId),
      jsonEncode(normalized),
      const Duration(minutes: 30),
    );
    await mergeProducts(normalized);
  }

  Future<List<Map<String, dynamic>>> readCategoryRecommended({
    required int categoryId,
  }) async {
    final String? raw = await _get(_Keys.categoryRecommended(categoryId));
    if (raw == null) return <Map<String, dynamic>>[];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded.cast<Map<String, dynamic>>();
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  /// Merge products into the shared products index so multiple views can reuse cached items.
  Future<void> mergeProducts(
    List<Map<String, dynamic>> products, {
    Duration ttl = const Duration(minutes: 30),
  }) async {
    if (products.isEmpty) return;

    final Map<int, Map<String, dynamic>> current = await _readProductsIndex();
    for (final Map<String, dynamic> product in products) {
      final Map<String, dynamic> normalized = _normalizeProduct(product);
      final int id = (normalized['id'] as num?)?.toInt() ?? 0;
      final int typeId =
          (normalized['id_tipo'] as num?)?.toInt() ??
          (normalized['typeId'] as num?)?.toInt() ??
          (normalized['productTypeId'] as num?)?.toInt() ??
          0;
      if (id <= 0 || typeId <= 0) continue;
      current[id] = normalized;
    }

    final Map<String, dynamic> serialisable = <String, dynamic>{};
    for (final MapEntry<int, Map<String, dynamic>> entry in current.entries) {
      serialisable[entry.key.toString()] = entry.value;
    }

    await _put(_Keys.productsIndex, jsonEncode(serialisable), ttl);
  }

  /// Read a single product from the shared index.
  Future<Map<String, dynamic>?> readProduct(int productId) async {
    final Map<int, Map<String, dynamic>> map = await _readProductsIndex();
    final Map<String, dynamic>? result = map[productId];
    return result == null ? null : Map<String, dynamic>.from(result);
  }

  /// Read all products currently stored in the index.
  Future<List<Map<String, dynamic>>> readAllProducts() async {
    final Map<int, Map<String, dynamic>> map = await _readProductsIndex();
    return map.values
        .map(
          (Map<String, dynamic> product) => Map<String, dynamic>.from(product),
        )
        .toList(growable: false);
  }

  /// Read products filtered by their type identifier.
  Future<List<Map<String, dynamic>>> readProductsByType(int typeId) async {
    final Map<int, Map<String, dynamic>> map = await _readProductsIndex();
    final List<Map<String, dynamic>> filtered = <Map<String, dynamic>>[];
    for (final Map<String, dynamic> product in map.values) {
      final int value =
          ((product['id_tipo'] ?? product['typeId'] ?? product['productTypeId'])
                  as num?)
              ?.toInt() ??
          -1;
      if (value == typeId) {
        filtered.add(Map<String, dynamic>.from(product));
      }
    }
    return filtered;
  }

  /// Read products for a list of identifiers.
  Future<List<Map<String, dynamic>>> readProductsByIds(
    Iterable<int> productIds,
  ) async {
    final Map<int, Map<String, dynamic>> map = await _readProductsIndex();
    final List<Map<String, dynamic>> results = <Map<String, dynamic>>[];
    for (final int id in productIds) {
      final Map<String, dynamic>? product = map[id];
      if (product != null) {
        results.add(Map<String, dynamic>.from(product));
      }
    }
    return results;
  }

  Future<Map<int, Map<String, dynamic>>> _readProductsIndex() async {
    final String? raw = await _get(_Keys.productsIndex);
    if (raw == null) return <int, Map<String, dynamic>>{};
    try {
      final Map<String, dynamic> decoded =
          jsonDecode(raw) as Map<String, dynamic>;
      final Map<int, Map<String, dynamic>> result =
          <int, Map<String, dynamic>>{};
      decoded.forEach((String key, dynamic value) {
        final int? id = int.tryParse(key);
        if (id == null || id <= 0 || value is! Map<String, dynamic>) return;
        result[id] = _normalizeProduct(value);
      });
      return result;
    } catch (_) {
      return <int, Map<String, dynamic>>{};
    }
  }

  Map<String, dynamic> _normalizeProduct(Map<String, dynamic> original) {
    final Map<String, dynamic> product = Map<String, dynamic>.from(original);

    final int id =
        (product['id'] as num?)?.toInt() ??
        (product['productId'] as num?)?.toInt() ??
        (product['producto_id'] as num?)?.toInt() ??
        0;
    product['id'] = id;

    final int typeId =
        (product['id_tipo'] as num?)?.toInt() ??
        (product['typeId'] as num?)?.toInt() ??
        (product['productTypeId'] as num?)?.toInt() ??
        0;
    product['id_tipo'] = typeId;
    product['typeId'] = typeId;
    product['productTypeId'] ??= typeId;

    final String name = (product['nombre'] ?? product['name'] ?? '').toString();
    product['nombre'] = name;
    product['name'] = name;

    final String description =
        (product['descripcion'] ?? product['description'] ?? '').toString();
    product['descripcion'] = description;
    product['description'] = description;

    final String imageUrl =
        (product['imagen_url'] ??
                product['imageUrl'] ??
                product['imagen'] ??
                '')
            .toString();
    product['imagen_url'] = imageUrl;
    product['imageUrl'] = imageUrl;

    final dynamic rawPrice = product['precio'] ?? product['price'];
    final double price = rawPrice is num
        ? rawPrice.toDouble()
        : double.tryParse(rawPrice?.toString() ?? '') ?? 0;
    product['precio'] = price;
    product['price'] = price;

    final dynamic rawAvailable =
        product['disponible'] ?? product['available'] ?? true;
    final bool available = rawAvailable is bool
        ? rawAvailable
        : rawAvailable is num
        ? rawAvailable != 0
        : rawAvailable.toString().toLowerCase() == 'true';
    product['disponible'] = available;
    product['available'] = available;

    final dynamic rawProductType = product['productType'];
    if (rawProductType is Map<String, dynamic>) {
      final Map<String, dynamic> type = Map<String, dynamic>.from(
        rawProductType,
      );
      type['id'] = (type['id'] as num?)?.toInt() ?? typeId;
      final String typeName =
          (type['nombre'] ?? type['name'] ?? product['productTypeName'] ?? '')
              .toString();
      type['nombre'] = typeName;
      type['name'] = typeName;
      product['productType'] = type;
      product['productTypeName'] = typeName;
    } else if (typeId > 0) {
      final String typeName = (product['productTypeName'] ?? '').toString();
      product['productType'] = <String, dynamic>{
        'id': typeId,
        'nombre': typeName,
        'name': typeName,
      };
      product['productTypeName'] = typeName;
    }

    return product;
  }

  List<Map<String, dynamic>> _normalizeProductsList(
    List<Map<String, dynamic>> products,
  ) {
    return products.map(_normalizeProduct).toList(growable: false);
  }
}
