import '../../core/result.dart';
import '../entities/order.dart';

abstract class OrderRepository {
  Future<Result<List<OrderEntity>>> getMyOrders();
  Future<Result<OrderEntity>> createOrder({
    required List<Map<String, int>> productos,
  });
}
