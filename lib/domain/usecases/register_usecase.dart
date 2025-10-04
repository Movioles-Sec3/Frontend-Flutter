import '../../core/result.dart';
import '../repositories/auth_repository.dart';

class RegisterUseCase {
  RegisterUseCase(this._repo);

  final AuthRepository _repo;

  Future<Result<void>> call({
    required String name,
    required String email,
    required String password,
  }) {
    return _repo.register(name: name, email: email, password: password);
  }
}
