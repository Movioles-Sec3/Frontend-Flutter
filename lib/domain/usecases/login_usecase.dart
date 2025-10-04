import '../../core/result.dart';
import '../repositories/auth_repository.dart';

class LoginUseCase {
  LoginUseCase(this._repo);

  final AuthRepository _repo;

  Future<Result<void>> call(String email, String password) {
    return _repo.login(email: email, password: password);
  }
}
