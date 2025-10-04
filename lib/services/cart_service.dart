import 'package:flutter/foundation.dart';

class CartItemData {
  CartItemData({
    required this.productId,
    required this.name,
    required this.imageUrl,
    required this.unitPrice,
    required this.quantity,
  });

  final int productId;
  final String name;
  final String imageUrl;
  final double unitPrice;
  int quantity;

  double get lineTotal => unitPrice * quantity;
}

class CartService extends ChangeNotifier {
  CartService._();
  static final CartService instance = CartService._();

  final Map<int, CartItemData> _itemsById = <int, CartItemData>{};

  List<CartItemData> get items => _itemsById.values.toList(growable: false);

  int get totalQuantity =>
      _itemsById.values.fold<int>(0, (int s, CartItemData e) => s + e.quantity);

  double get subtotal => _itemsById.values.fold<double>(
    0,
    (double s, CartItemData e) => s + e.lineTotal,
  );

  void addOrIncrement({
    required int productId,
    required String name,
    required String imageUrl,
    required double unitPrice,
  }) {
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
  }

  void decrementOrRemove(int productId) {
    final CartItemData? existing = _itemsById[productId];
    if (existing == null) return;
    if (existing.quantity > 1) {
      existing.quantity -= 1;
    } else {
      _itemsById.remove(productId);
    }
    notifyListeners();
  }

  int getQuantity(int productId) => _itemsById[productId]?.quantity ?? 0;

  void setQuantity(int productId, int quantity) {
    if (quantity <= 0) {
      _itemsById.remove(productId);
      notifyListeners();
      return;
    }
    final CartItemData? existing = _itemsById[productId];
    if (existing != null) {
      existing.quantity = quantity;
      notifyListeners();
    }
  }

  void remove(int productId) {
    if (_itemsById.remove(productId) != null) {
      notifyListeners();
    }
  }

  void clear() {
    _itemsById.clear();
    notifyListeners();
  }

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

  /// Adds all products from a previous order to the cart
  void reorderFromOrder(List<Map<String, dynamic>> orderProducts) {
    for (final Map<String, dynamic> product in orderProducts) {
      final int productId = (product['id_producto'] as num?)?.toInt() ?? 0;
      final int quantity = (product['cantidad'] as num?)?.toInt() ?? 0;
      final String name = (product['nombre'] ?? '').toString();
      final String imageUrl = (product['imagen_url'] ?? '').toString();
      final double unitPrice = ((product['precio'] ?? 0) as num).toDouble();

      if (productId > 0 && quantity > 0) {
        // Add or update the product in cart
        final CartItemData? existing = _itemsById[productId];
        if (existing != null) {
          existing.quantity += quantity;
        } else {
          _itemsById[productId] = CartItemData(
            productId: productId,
            name: name,
            imageUrl: imageUrl,
            unitPrice: unitPrice,
            quantity: quantity,
          );
        }
      }
    }
    notifyListeners();
  }
}
