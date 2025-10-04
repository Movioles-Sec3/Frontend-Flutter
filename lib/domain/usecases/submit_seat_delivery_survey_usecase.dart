import '../../core/result.dart';
import '../repositories/user_repository.dart';

class SubmitSeatDeliverySurveyUseCase {
  SubmitSeatDeliverySurveyUseCase(this._repository);

  final UserRepository _repository;

  Future<Result<void>> call({
    required String interestLevel,
    required int extraMinutes,
    String? comments,
  }) {
    return _repository.submitSeatDeliverySurvey(
      interestLevel: interestLevel,
      extraMinutes: extraMinutes,
      comments: comments,
    );
  }
}
