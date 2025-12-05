import '../../core/api_client.dart';
import '../../core/result.dart';
import '../../domain/entities/order.dart';
import '../../domain/repositories/order_repository.dart';
import '../../services/orders_db.dart';

class OrderRepositoryImpl implements OrderRepository {
  OrderRepositoryImpl(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<Result<List<OrderEntity>>> getMyOrders() async {
    final Result<dynamic> res = await _apiClient.get('/compras/me', auth: true);
    if (res.isFailure) return Result.failure(res.error!);
    if (res.data is List) {
      final List<OrderEntity> items = (res.data as List)
          .whereType<Map<String, dynamic>>()
          .map(OrderEntity.fromJson)
          .toList();
      return Result.success(items);
    }
    return Result.failure('Invalid server response');
  }

  @override
  Future<Result<OrderEntity>> createOrder({
    required List<Map<String, int>> productos,
  }) async {
    final Result<dynamic> res = await _apiClient.post(
      '/compras/',
      body: <String, dynamic>{'productos': productos},
      auth: true,
    );
    if (res.isFailure) return Result.failure(res.error!);
    if (res.data is Map<String, dynamic>) {
      return Result.success(
        OrderEntity.fromJson(res.data as Map<String, dynamic>),
      );
    }
    return Result.failure('Invalid server response');
  }

  @override
  Future<Result<List<Map<String, dynamic>>>> getOrderDetails(int orderId) async {
    final Result<dynamic> res = await _apiClient.get(
      '/compras/$orderId/productos',
      auth: true,
    );

    if (res.isSuccess && res.data is List) {
      final List<Map<String, dynamic>> products = (res.data as List)
          .whereType<Map<String, dynamic>>()
          .toList();

      // Cache the order details in the database for offline access
      try {
        await OrdersDb.instance.upsertOrder(
          id: orderId,
          orderNumber: orderId.toString(),
          total: products.fold<double>(
            0.0,
            (sum, item) {
              final qty = ((item['cantidad'] ?? 0) as num).toInt();
              final price = ((item['precio'] ?? 0) as num).toDouble();
              return sum + (qty * price);
            },
          ),
          status: 'completed', // We don't know the actual status here
          placedAt: DateTime.now().toIso8601String(),
          items: products.map((p) => <String, dynamic>{
            'productId': (p['id_producto'] as num?)?.toInt() ?? 0,
            'name': (p['nombre'] ?? '').toString(),
            'quantity': (p['cantidad'] as num?)?.toInt() ?? 0,
            'unitPrice': ((p['precio'] ?? 0) as num).toDouble(),
          }).toList(),
        );
      } catch (_) {
        // Cache error shouldn't affect the success result
      }

      return Result.success(products);
    }

    // API failed, try to get from cache
    try {
      final List<Map<String, dynamic>> cachedItems = await OrdersDb.instance.getOrderItems(orderId);

      if (cachedItems.isNotEmpty) {
        // Convert cached format to API format
        final List<Map<String, dynamic>> products = cachedItems.map((item) => <String, dynamic>{
          'id_producto': item['product_id'],
          'nombre': item['name'],
          'cantidad': item['quantity'],
          'precio': item['unit_price'],
          'imagen_url': '', // Not stored in cache
        }).toList();

        return Result.success(products);
      }
    } catch (_) {
      // Cache read failed, continue to error
    }

    return Result.failure(res.error ?? 'Invalid server response');
  }
}
