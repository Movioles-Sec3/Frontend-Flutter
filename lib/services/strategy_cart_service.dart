import 'package:flutter/foundation.dart';
import '../core/strategies/caching_strategy.dart';
import '../core/strategies/payment_strategy.dart';
import '../core/strategies/validation_strategy.dart';
import '../di/injector.dart';
import 'cart_service.dart';

/// Enhanced cart service that uses strategy pattern
class StrategyCartService extends ChangeNotifier {
  StrategyCartService._();
  static final StrategyCartService instance = StrategyCartService._();

  final Map<int, CartItemData> _itemsById = <int, CartItemData>{};
  late final CacheContext<String> _cacheContext;
  late final PaymentContext _paymentContext;
  late final ValidationContext _validationContext;

  /// Initialize the service with strategy contexts
  void initialize() {
    _cacheContext = injector.get<CacheContext<String>>();
    _paymentContext = injector.get<PaymentContext>();
    _validationContext = injector.get<ValidationContext>();
    
    // Load cart from cache
    _loadCartFromCache();
  }

  List<CartItemData> get items => _itemsById.values.toList(growable: false);

  int get totalQuantity =>
      _itemsById.values.fold<int>(0, (int s, CartItemData e) => s + e.quantity);

  double get subtotal => _itemsById.values.fold<double>(
    0,
    (double s, CartItemData e) => s + e.lineTotal,
  );

  /// Add or increment item using validation strategy
  Future<void> addOrIncrement({
    required int productId,
    required String name,
    required String imageUrl,
    required double unitPrice,
  }) async {
    // Validate input data
    final validationData = {
      'productId': productId,
      'name': name,
      'imageUrl': imageUrl,
      'unitPrice': unitPrice,
    };

    final validationResult = await _validationContext.validate(validationData);
    if (!validationResult.isValid) {
      throw Exception('Validation failed: ${validationResult.errors.join(', ')}');
    }

    final CartItemData? existing = _itemsById[productId];
    if (existing != null) {
      existing.quantity += 1;
    } else {
      _itemsById[productId] = CartItemData(
        productId: productId,
        name: name,
        imageUrl: imageUrl,
        unitPrice: unitPrice,
        quantity: 1,
      );
    }

    notifyListeners();
    await _saveCartToCache();
  }

  /// Decrement or remove item
  Future<void> decrementOrRemove(int productId) async {
    final CartItemData? existing = _itemsById[productId];
    if (existing == null) return;
    
    if (existing.quantity > 1) {
      existing.quantity -= 1;
    } else {
      _itemsById.remove(productId);
    }
    
    notifyListeners();
    await _saveCartToCache();
  }

  /// Set quantity with validation
  Future<void> setQuantity(int productId, int quantity) async {
    // Validate quantity
    final validationResult = await _validationContext.validate(quantity, strategyId: 'quantity');
    if (!validationResult.isValid) {
      throw Exception('Invalid quantity: ${validationResult.errors.join(', ')}');
    }

    if (quantity <= 0) {
      _itemsById.remove(productId);
      notifyListeners();
      await _saveCartToCache();
      return;
    }
    
    final CartItemData? existing = _itemsById[productId];
    if (existing != null) {
      existing.quantity = quantity;
      notifyListeners();
      await _saveCartToCache();
    }
  }

  int getQuantity(int productId) => _itemsById[productId]?.quantity ?? 0;

  /// Remove item
  Future<void> remove(int productId) async {
    if (_itemsById.remove(productId) != null) {
      notifyListeners();
      await _saveCartToCache();
    }
  }

  /// Clear cart
  Future<void> clear() async {
    _itemsById.clear();
    notifyListeners();
    await _saveCartToCache();
  }

  /// Process payment using strategy pattern
  Future<PaymentResult> processPayment({
    required String paymentMethodId,
    required String orderId,
  }) async {
    final paymentData = PaymentData(
      amount: subtotal,
      currency: 'USD',
      orderId: orderId,
      paymentMethodId: paymentMethodId,
      metadata: {
        'itemCount': totalQuantity,
        'items': _itemsById.values.map((e) => {
          'productId': e.productId,
          'name': e.name,
          'quantity': e.quantity,
          'unitPrice': e.unitPrice,
        }).toList(),
      },
    );

    return await _paymentContext.processPayment(paymentData);
  }

  /// Get available payment methods
  List<String> getAvailablePaymentMethods() {
    return _paymentContext.getAvailablePaymentMethods();
  }

  /// Convert to order payload
  List<Map<String, int>> toOrderProductosPayload() {
    return _itemsById.values
        .map(
          (CartItemData e) => <String, int>{
            'id_producto': e.productId,
            'cantidad': e.quantity,
          },
        )
        .toList(growable: false);
  }

  /// Save cart to cache using strategy pattern
  Future<void> _saveCartToCache() async {
    try {
      final cartData = _itemsById.values.map((item) => {
        'productId': item.productId,
        'name': item.name,
        'imageUrl': item.imageUrl,
        'unitPrice': item.unitPrice,
        'quantity': item.quantity,
      }).toList();

      final cartJson = cartData.toString();
      await _cacheContext.store(
        'cart_data',
        cartJson,
        expiration: const Duration(hours: 24),
      );
    } catch (e) {
      debugPrint('Failed to save cart to cache: $e');
    }
  }

  /// Load cart from cache using strategy pattern
  Future<void> _loadCartFromCache() async {
    try {
      final result = await _cacheContext.retrieve('cart_data');
      if (result.success && result.data != null) {
        // Parse cart data and restore items
        // This is a simplified implementation
        // In a real app, you'd have proper JSON serialization
        debugPrint('Cart loaded from cache: ${result.data}');
      }
    } catch (e) {
      debugPrint('Failed to load cart from cache: $e');
    }
  }
}
