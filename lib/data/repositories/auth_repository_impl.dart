import '../../core/api_client.dart';
import '../../core/result.dart';
import '../../services/session_manager.dart';
import '../../domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<Result<void>> login({
    required String email,
    required String password,
  }) async {
    final Result<dynamic> res = await _apiClient.post(
      '/usuarios/token',
      body: <String, dynamic>{'email': email, 'password': password},
      auth: false,
    );
    if (res.isFailure) return Result.failure(res.error!);
    final dynamic data = res.data;
    final String accessToken = data['access_token']?.toString() ?? '';
    final String tokenType = data['token_type']?.toString() ?? 'Bearer';
    if (accessToken.isEmpty) return Result.failure('Invalid token');
    await SessionManager.saveToken(
      accessToken: accessToken,
      tokenType: tokenType,
    );
    return Result.success(null);
  }

  @override
  Future<Result<void>> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final Result<dynamic> res = await _apiClient.post(
      '/usuarios/',
      body: <String, dynamic>{
        'nombre': name,
        'email': email,
        'password': password,
      },
      auth: false,
    );
    if (res.isFailure) return Result.failure(res.error!);
    return Result.success(null);
  }

  @override
  Future<void> logout() async {
    await SessionManager.clear();
  }
}
