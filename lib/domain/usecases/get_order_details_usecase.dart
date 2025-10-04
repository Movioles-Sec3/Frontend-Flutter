import '../../core/result.dart';
import '../repositories/order_repository.dart';

class GetOrderDetailsUseCase {
  GetOrderDetailsUseCase(this._repo);

  final OrderRepository _repo;

  Future<Result<List<Map<String, dynamic>>>> call(int orderId) {
    return _repo.getOrderDetails(orderId);
  }
}
