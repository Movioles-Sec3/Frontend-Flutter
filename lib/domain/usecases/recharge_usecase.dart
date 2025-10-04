import '../../core/result.dart';
import '../entities/user.dart';
import '../repositories/user_repository.dart';

class RechargeUseCase {
  RechargeUseCase(this._repo);

  final UserRepository _repo;

  Future<Result<UserEntity>> call(double amount) {
    return _repo.recharge(amount);
  }
}
