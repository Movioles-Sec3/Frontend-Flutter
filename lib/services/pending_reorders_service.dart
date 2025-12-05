import 'dart:async';
import 'dart:convert';
import '../core/strategies/caching_strategy.dart';
import '../di/injector.dart';
import 'connectivity_service.dart';
import 'cart_service.dart';
import 'orders_db.dart';
import 'product_local_storage.dart';
import 'local_catalog_storage.dart';

/// Service to handle pending reorders with eventual connectivity support
class PendingReordersService {
  PendingReordersService._();
  static final PendingReordersService instance = PendingReordersService._();

  static const String _storageKey = 'pending_reorders';
  CacheContext<String> get _cache => injector.get<CacheContext<String>>();

  StreamSubscription<bool>? _connectivitySub;
  bool _isProcessing = false;

  // Stream controller to notify when reorders are successfully processed
  final StreamController<int> _reorderSuccessController = StreamController<int>.broadcast();
  Stream<int> get reorderSuccess$ => _reorderSuccessController.stream;

  /// Initialize the service to listen for connectivity changes
  Future<void> initialize() async {
    _connectivitySub?.cancel();
    _connectivitySub = ConnectivityService.instance.online$.listen((bool online) {
      if (online && !_isProcessing) {
        // When we come back online, process pending reorders
        _processPendingReorders();
      }
    });

    // Also process on startup if online
    if (ConnectivityService.instance.isOnline) {
      await _processPendingReorders();
    }
  }

  /// Add a pending reorder request
  Future<void> addPendingReorder(int orderId) async {
    final List<Map<String, dynamic>> pending = await _readPendingReorders();

    // Add the new reorder request with timestamp
    pending.add({
      'orderId': orderId,
      'timestamp': DateTime.now().toIso8601String(),
    });

    await _savePendingReorders(pending);
  }

  /// Process all pending reorders
  Future<void> _processPendingReorders() async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      final List<Map<String, dynamic>> pending = await _readPendingReorders();
      if (pending.isEmpty) {
        _isProcessing = false;
        return;
      }

      final List<Map<String, dynamic>> failedReorders = [];
      final CartService cartService = CartService.instance;
      int successCount = 0;

      for (final Map<String, dynamic> reorderRequest in pending) {
        final int orderId = (reorderRequest['orderId'] as num?)?.toInt() ?? 0;
        if (orderId <= 0) continue;

        try {
          // Fetch order items from local database
          final List<Map<String, dynamic>> orderItems = await OrdersDb.instance.getOrderItems(orderId);

          if (orderItems.isNotEmpty) {
            // Initialize product cache to fetch image URLs
            final ProductLocalStorage productCache = ProductLocalStorage();
            await productCache.init();

            // Fetch all products first to build an image URL map
            final Map<int, String> imageUrlMap = <int, String>{};
            for (final item in orderItems) {
              final int productId = (item['product_id'] as num?)?.toInt() ?? 0;
              if (productId > 0 && !imageUrlMap.containsKey(productId)) {
                try {
                  // First try: LocalCatalogStorage (main catalog/home page products)
                  final catalogProduct = await LocalCatalogStorage.instance.readProduct(productId);
                  if (catalogProduct != null) {
                    final String imageUrl = (catalogProduct['imagen_url'] ?? catalogProduct['imageUrl'] ?? '').toString();
                    if (imageUrl.isNotEmpty) {
                      imageUrlMap[productId] = imageUrl;
                      continue;
                    }
                  }

                  // Second try: ProductLocalStorage (browsed products cache)
                  final product = await productCache.getProduct(productId);
                  if (product != null && product.imageUrl.isNotEmpty) {
                    imageUrlMap[productId] = product.imageUrl;
                  }
                } catch (_) {
                  // If cache fails, continue to next product
                }
              }
            }

            // Convert database format to cart format with image URLs
            final List<Map<String, dynamic>> products = orderItems.map((item) {
              final int productId = (item['product_id'] as num?)?.toInt() ?? 0;
              final String imageUrl = imageUrlMap[productId] ?? '';

              return <String, dynamic>{
                'id_producto': productId,
                'nombre': item['name'],
                'cantidad': item['quantity'],
                'precio': item['unit_price'],
                'imagen_url': imageUrl,
              };
            }).toList();

            // Successfully got order details, add to cart
            cartService.reorderFromOrder(products);
            successCount++;
          } else {
            // No items found, keep for retry (maybe not synced yet)
            failedReorders.add(reorderRequest);
          }
        } catch (_) {
          // Error occurred, keep for retry
          failedReorders.add(reorderRequest);
        }
      }

      // Save only the failed reorders for retry
      await _savePendingReorders(failedReorders);

      // Notify if any reorders were successful
      if (successCount > 0) {
        _reorderSuccessController.add(successCount);
      }
    } finally {
      _isProcessing = false;
    }
  }

  /// Check if there are pending reorders
  Future<bool> hasPendingReorders() async {
    final List<Map<String, dynamic>> pending = await _readPendingReorders();
    return pending.isNotEmpty;
  }

  /// Get count of pending reorders
  Future<int> getPendingCount() async {
    final List<Map<String, dynamic>> pending = await _readPendingReorders();
    return pending.length;
  }

  /// Clear all pending reorders
  Future<void> clearPendingReorders() async {
    await _cache.remove(_storageKey);
  }

  Future<List<Map<String, dynamic>>> _readPendingReorders() async {
    final res = await _cache.retrieve(_storageKey);
    if (res.success && res.data != null && res.data!.isNotEmpty) {
      try {
        final decoded = jsonDecode(res.data!) as List<dynamic>;
        return decoded.cast<Map<String, dynamic>>();
      } catch (_) {
        return <Map<String, dynamic>>[];
      }
    }
    return <Map<String, dynamic>>[];
  }

  Future<void> _savePendingReorders(List<Map<String, dynamic>> pending) async {
    if (pending.isEmpty) {
      await _cache.remove(_storageKey);
    } else {
      final String payload = jsonEncode(pending);
      await _cache.store(_storageKey, payload, expiration: const Duration(days: 7));
    }
  }

  void dispose() {
    _connectivitySub?.cancel();
    _reorderSuccessController.close();
  }
}

