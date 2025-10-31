import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';

class _Keys {
  // Home
  static const String homeFeed = 'home:feed:v1';
  static const String homeLayout = 'home:layout:v1';
  static const String homeRecommended = 'home:recommended:v1';

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
    await _put(_Keys.categoryPage(categoryId, page), jsonEncode(products), ttl);
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
    await _put(
      _Keys.homeRecommended,
      jsonEncode(products),
      const Duration(minutes: 30),
    );
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
    await _put(
      _Keys.categoryRecommended(categoryId),
      jsonEncode(products),
      const Duration(minutes: 30),
    );
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
}
