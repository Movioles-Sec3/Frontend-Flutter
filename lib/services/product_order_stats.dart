import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Service to track and retrieve product order frequency statistics
class ProductOrderStats {
  ProductOrderStats._();
  static final ProductOrderStats instance = ProductOrderStats._();

  static const String _orderCountKey = 'product_order_count_v1';
  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  Future<SharedPreferences> get _preferences async {
    if (_prefs == null) {
      await init();
    }
    return _prefs!;
  }

  /// Record that a product was ordered
  Future<void> recordProductOrder(int productId, {int quantity = 1}) async {
    try {
      final prefs = await _preferences;
      final counts = await getOrderCounts();

      // Increment the count
      counts[productId] = (counts[productId] ?? 0) + quantity;

      // Save back
      await prefs.setString(_orderCountKey, jsonEncode(counts));
    } catch (_) {
      // Silently fail
    }
  }

  /// Record multiple products ordered (e.g., from an order)
  Future<void> recordMultipleProducts(Map<int, int> productQuantities) async {
    try {
      final prefs = await _preferences;
      final counts = await getOrderCounts();

      // Merge quantities
      for (final entry in productQuantities.entries) {
        counts[entry.key] = (counts[entry.key] ?? 0) + entry.value;
      }

      // Save back
      await prefs.setString(_orderCountKey, jsonEncode(counts));
    } catch (_) {
      // Silently fail
    }
  }

  /// Get order counts for all products
  Future<Map<int, int>> getOrderCounts() async {
    try {
      final prefs = await _preferences;
      final String? json = prefs.getString(_orderCountKey);

      if (json == null || json.isEmpty) {
        return {};
      }

      final Map<String, dynamic> decoded = jsonDecode(json) as Map<String, dynamic>;

      // Convert string keys to int keys
      return decoded.map((key, value) =>
        MapEntry(int.parse(key), (value as num).toInt())
      );
    } catch (_) {
      return {};
    }
  }

  /// Get order count for a specific product
  Future<int> getProductOrderCount(int productId) async {
    final counts = await getOrderCounts();
    return counts[productId] ?? 0;
  }

  /// Get product IDs sorted by order frequency (most ordered first)
  Future<List<int>> getMostOrderedProductIds() async {
    final counts = await getOrderCounts();

    // Sort by count descending
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.map((e) => e.key).toList();
  }

  /// Clear all order statistics
  Future<void> clear() async {
    try {
      final prefs = await _preferences;
      await prefs.remove(_orderCountKey);
    } catch (_) {
      // Silently fail
    }
  }

  /// Get statistics summary
  Future<Map<String, dynamic>> getStats() async {
    final counts = await getOrderCounts();

    return {
      'totalProducts': counts.length,
      'totalOrders': counts.values.fold<int>(0, (sum, count) => sum + count),
      'mostOrdered': counts.entries.isEmpty
          ? null
          : counts.entries.reduce((a, b) => a.value > b.value ? a : b).key,
    };
  }
}

