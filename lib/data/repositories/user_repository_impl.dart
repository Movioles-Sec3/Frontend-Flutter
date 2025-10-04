import '../../core/api_client.dart';
import '../../core/result.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/user_repository.dart';

class UserRepositoryImpl implements UserRepository {
  UserRepositoryImpl(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<Result<UserEntity>> getMe() async {
    final Result<dynamic> res = await _apiClient.get(
      '/usuarios/me',
      auth: true,
    );
    if (res.isFailure) return Result.failure(res.error!);
    if (res.data is Map<String, dynamic>) {
      return Result.success(
        UserEntity.fromJson(res.data as Map<String, dynamic>),
      );
    }
    return Result.failure('Invalid server response');
  }

  @override
  Future<Result<UserEntity>> recharge(double amount) async {
    final Result<dynamic> res = await _apiClient.post(
      '/usuarios/me/recargar',
      body: <String, dynamic>{'monto': amount},
      auth: true,
    );
    if (res.isFailure) return Result.failure(res.error!);
    if (res.data is Map<String, dynamic>) {
      return Result.success(
        UserEntity.fromJson(res.data as Map<String, dynamic>),
      );
    }
    return Result.failure('Invalid server response');
  }

  @override
  Future<Result<void>> submitSeatDeliverySurvey({
    required String interestLevel,
    required int extraMinutes,
    String? comments,
  }) async {
    final Result<dynamic> res = await _apiClient.post(
      '/usuarios/me/encuesta',
      body: <String, dynamic>{
        'nivel_interes': interestLevel,
        'minutos_extra': extraMinutes,
        'comentarios': comments ?? '',
      },
      auth: true,
    );
    if (res.isFailure) return Result.failure(res.error!);
    return Result.success(null);
  }
}
