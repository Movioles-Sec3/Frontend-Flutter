import '../../core/result.dart';

abstract class AuthRepository {
  Future<Result<void>> login({required String email, required String password});
  Future<Result<void>> register({
    required String name,
    required String email,
    required String password,
  });
  Future<void> logout();
}
