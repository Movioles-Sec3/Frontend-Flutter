import '../../core/result.dart';
import '../entities/order.dart';
import '../repositories/order_repository.dart';

class GetMyOrdersUseCase {
  GetMyOrdersUseCase(this._repo);

  final OrderRepository _repo;

  Future<Result<List<OrderEntity>>> call() {
    return _repo.getMyOrders();
  }
}
