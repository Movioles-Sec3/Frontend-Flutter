import '../../core/result.dart';
import '../entities/user.dart';
import '../repositories/user_repository.dart';

class GetMeUseCase {
  GetMeUseCase(this._repo);

  final UserRepository _repo;

  Future<Result<UserEntity>> call() {
    return _repo.getMe();
  }
}
