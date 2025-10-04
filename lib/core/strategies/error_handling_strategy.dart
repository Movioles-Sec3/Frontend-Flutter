import 'strategy.dart';

/// Error handling result
class ErrorHandlingResult {
  ErrorHandlingResult({
    required this.shouldRetry,
    required this.userMessage,
    this.technicalDetails,
    this.suggestedAction,
  });

  final bool shouldRetry;
  final String userMessage;
  final String? technicalDetails;
  final String? suggestedAction;
}

/// Base error handling strategy
abstract class ErrorHandlingStrategy extends Strategy<Exception, ErrorHandlingResult> {
  @override
  String get identifier;

  @override
  bool canHandle(Exception input) => true;
}

/// Network error handling strategy
class NetworkErrorHandlingStrategy extends ErrorHandlingStrategy {
  @override
  String get identifier => 'network';

  @override
  bool canHandle(Exception input) {
    return input.toString().contains('SocketException') ||
           input.toString().contains('Connection refused') ||
           input.toString().contains('Network error');
  }

  @override
  Future<ErrorHandlingResult> execute(Exception input) async {
    final errorMessage = input.toString();
    
    if (errorMessage.contains('Connection refused')) {
      return ErrorHandlingResult(
        shouldRetry: true,
        userMessage: 'Unable to connect to the server. Please check your internet connection and try again.',
        technicalDetails: 'Connection refused - server may be down or unreachable',
        suggestedAction: 'Check if the backend server is running on the correct port',
      );
    }
    
    if (errorMessage.contains('SocketException')) {
      return ErrorHandlingResult(
        shouldRetry: true,
        userMessage: 'Network connection failed. Please check your internet connection.',
        technicalDetails: 'SocketException: ${input.toString()}',
        suggestedAction: 'Verify network connectivity and server availability',
      );
    }

    return ErrorHandlingResult(
      shouldRetry: true,
      userMessage: 'A network error occurred. Please try again.',
      technicalDetails: errorMessage,
      suggestedAction: 'Check network connection and server status',
    );
  }
}

/// Authentication error handling strategy
class AuthenticationErrorHandlingStrategy extends ErrorHandlingStrategy {
  @override
  String get identifier => 'authentication';

  @override
  bool canHandle(Exception input) {
    return input.toString().contains('401') ||
           input.toString().contains('Unauthorized') ||
           input.toString().contains('authentication');
  }

  @override
  Future<ErrorHandlingResult> execute(Exception input) async {
    return ErrorHandlingResult(
      shouldRetry: false,
      userMessage: 'Authentication failed. Please check your credentials and try again.',
      technicalDetails: input.toString(),
      suggestedAction: 'Verify username and password are correct',
    );
  }
}

/// Validation error handling strategy
class ValidationErrorHandlingStrategy extends ErrorHandlingStrategy {
  @override
  String get identifier => 'validation';

  @override
  bool canHandle(Exception input) {
    return input.toString().contains('400') ||
           input.toString().contains('validation') ||
           input.toString().contains('Invalid');
  }

  @override
  Future<ErrorHandlingResult> execute(Exception input) async {
    return ErrorHandlingResult(
      shouldRetry: false,
      userMessage: 'Please check your input and try again.',
      technicalDetails: input.toString(),
      suggestedAction: 'Verify all required fields are filled correctly',
    );
  }
}

/// Server error handling strategy
class ServerErrorHandlingStrategy extends ErrorHandlingStrategy {
  @override
  String get identifier => 'server';

  @override
  bool canHandle(Exception input) {
    return input.toString().contains('500') ||
           input.toString().contains('Internal Server Error') ||
           input.toString().contains('server');
  }

  @override
  Future<ErrorHandlingResult> execute(Exception input) async {
    return ErrorHandlingResult(
      shouldRetry: true,
      userMessage: 'Server error occurred. Please try again later.',
      technicalDetails: input.toString(),
      suggestedAction: 'Contact support if the problem persists',
    );
  }
}

/// Default error handling strategy
class DefaultErrorHandlingStrategy extends ErrorHandlingStrategy {
  @override
  String get identifier => 'default';

  @override
  Future<ErrorHandlingResult> execute(Exception input) async {
    return ErrorHandlingResult(
      shouldRetry: true,
      userMessage: 'An unexpected error occurred. Please try again.',
      technicalDetails: input.toString(),
      suggestedAction: 'Contact support if the problem persists',
    );
  }
}

/// Error handling context
class ErrorHandlingContext {
  ErrorHandlingContext({
    required this.defaultStrategy,
    this.strategies = const [],
  });

  final ErrorHandlingStrategy defaultStrategy;
  final List<ErrorHandlingStrategy> strategies;

  /// Handle error using appropriate strategy
  Future<ErrorHandlingResult> handleError(Exception error) async {
    final strategy = _selectStrategy(error);
    return await strategy.execute(error);
  }

  /// Select error handling strategy based on error type
  ErrorHandlingStrategy _selectStrategy(Exception error) {
    for (final strategy in strategies) {
      if (strategy.canHandle(error)) {
        return strategy;
      }
    }
    return defaultStrategy;
  }

  /// Add an error handling strategy
  void addStrategy(ErrorHandlingStrategy strategy) {
    strategies.add(strategy);
  }
}
