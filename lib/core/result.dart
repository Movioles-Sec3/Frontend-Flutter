class Result<T> {
  Result._({this.data, this.error});

  final T? data;
  final String? error;

  bool get isSuccess => error == null;
  bool get isFailure => !isSuccess;

  static Result<T> success<T>(T data) => Result<T>._(data: data);
  static Result<T> failure<T>(String message) => Result<T>._(error: message);
}
