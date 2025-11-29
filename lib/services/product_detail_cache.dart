import 'dart:collection';

import '../core/models/product_detail_data.dart';

/// Simple LRU cache for prepared product detail data.
class ProductDetailCache {
  ProductDetailCache._(this.maxEntries);

  static final ProductDetailCache instance = ProductDetailCache._(
    _defaultMaxEntries,
  );

  static const int _defaultMaxEntries = 20;

  final int maxEntries;
  final LinkedHashMap<int, PreparedProductData> _store =
      LinkedHashMap<int, PreparedProductData>();

  PreparedProductData? get(int productId) {
    final PreparedProductData? value = _store.remove(productId);
    if (value != null) {
      // Reinsert to mark as most recently used.
      _store[productId] = value;
    }
    return value;
  }

  void put(PreparedProductData data) {
    _store.remove(data.id);
    _store[data.id] = data;
    if (_store.length > maxEntries) {
      // Remove least recently used (first entry).
      _store.remove(_store.keys.first);
    }
  }

  void clear() => _store.clear();
}
