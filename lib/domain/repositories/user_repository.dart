import '../../core/result.dart';
import '../entities/user.dart';

abstract class UserRepository {
  Future<Result<UserEntity>> getMe();
  Future<Result<UserEntity>> recharge(double amount);
  Future<Result<void>> submitSeatDeliverySurvey({
    required String interestLevel,
    required int extraMinutes,
    String? comments,
  });
}
