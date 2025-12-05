import 'dart:async';

import '../../core/result.dart';
import '../../services/connectivity_service.dart';
import '../repositories/user_repository.dart';

class SubmitSeatDeliverySurveyUseCase {
  SubmitSeatDeliverySurveyUseCase(this._repository);

  final UserRepository _repository;
  static const Duration _timeout = Duration(seconds: 10);

  Future<Result<void>> call({
    required String interestLevel,
    required int extraMinutes,
    String? comments,
  }) async {
    // Check connectivity first
    await ConnectivityService.instance.initialize();
    final bool isOnline = ConnectivityService.instance.isOnline;

    if (!isOnline) {
      return Result.failure(
        'No internet connection. Please check your connection and try again.',
      );
    }

    try {
      final result = await _repository.submitSeatDeliverySurvey(
        interestLevel: interestLevel,
        extraMinutes: extraMinutes,
        comments: comments,
      ).timeout(
        _timeout,
        onTimeout: () {
          return Result.failure(
            'Connection timed out. Please check your internet connection.',
          );
        },
      );

      return result;
    } on TimeoutException {
      return Result.failure(
        'Connection timed out. Please check your internet connection.',
      );
    } catch (e) {
      // Check if it's a network error
      final String errorStr = e.toString().toLowerCase();
      if (errorStr.contains('socket') ||
          errorStr.contains('network') ||
          errorStr.contains('failed host lookup') ||
          errorStr.contains('connection')) {
        return Result.failure(
          'No internet connection. Please check your connection and try again.',
        );
      }
      rethrow;
    }
  }
}
