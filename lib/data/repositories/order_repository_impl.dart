import '../../core/api_client.dart';
import '../../core/result.dart';
import '../../domain/entities/order.dart';
import '../../domain/repositories/order_repository.dart';

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
}
