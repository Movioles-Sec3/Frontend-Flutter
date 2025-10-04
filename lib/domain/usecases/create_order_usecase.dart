import '../../core/result.dart';
import '../entities/order.dart';
import '../repositories/order_repository.dart';

class CreateOrderUseCase {
  CreateOrderUseCase(this._repo);

  final OrderRepository _repo;

  Future<Result<OrderEntity>> call(List<Map<String, int>> productos) {
    return _repo.createOrder(productos: productos);
  }
}
