import 'dart:convert';

import '../core/strategies/caching_strategy.dart';
import '../di/injector.dart';

/// Keys for local storage
class _Keys {
  static const String ordersList = 'orders_list';
  static const String lastOrder = 'last_order';
  static const String pendingOrders = 'pending_orders';
}

/// Service to persist and retrieve orders locally using the app's CacheContext<String>.
class LocalOrdersStorage {
  LocalOrdersStorage._();
  static final LocalOrdersStorage instance = LocalOrdersStorage._();

  CacheContext<String> get _cache => injector.get<CacheContext<String>>();

  Future<void> saveOrders(List<Map<String, dynamic>> orders) async {
    final String payload = jsonEncode(orders);
    await _cache.store(_Keys.ordersList, payload, expiration: const Duration(days: 7));
  }

  Future<List<Map<String, dynamic>>> readOrders() async {
    final res = await _cache.retrieve(_Keys.ordersList);
    if (res.success && res.data != null) {
      try {
        final decoded = jsonDecode(res.data!) as List<dynamic>;
        return decoded.cast<Map<String, dynamic>>();
      } catch (_) {
        return <Map<String, dynamic>>[];
      }
    }
    return <Map<String, dynamic>>[];
  }

  Future<void> saveLastOrder(Map<String, dynamic> order) async {
    final String payload = jsonEncode(order);
    await _cache.store(_Keys.lastOrder, payload, expiration: const Duration(days: 3));
  }

  Future<Map<String, dynamic>?> readLastOrder() async {
    final res = await _cache.retrieve(_Keys.lastOrder);
    if (res.success && res.data != null) {
      try {
        return jsonDecode(res.data!) as Map<String, dynamic>;
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  Future<void> clearLastOrder() async {
    await _cache.remove(_Keys.lastOrder);
  }

  // Pending orders outbox (for eventual connectivity)
  Future<void> savePendingOrders(List<Map<String, dynamic>> pending) async {
    final String payload = jsonEncode(pending);
    await _cache.store(_Keys.pendingOrders, payload, expiration: const Duration(days: 7));
  }

  Future<List<Map<String, dynamic>>> readPendingOrders() async {
    final res = await _cache.retrieve(_Keys.pendingOrders);
    if (res.success && res.data != null) {
      try {
        final decoded = jsonDecode(res.data!) as List<dynamic>;
        return decoded.cast<Map<String, dynamic>>();
      } catch (_) {
        return <Map<String, dynamic>>[];
      }
    }
    return <Map<String, dynamic>>[];
  }

  Future<void> clearPendingOrders() async {
    await _cache.remove(_Keys.pendingOrders);
  }
}


