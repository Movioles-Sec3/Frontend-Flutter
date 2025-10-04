import 'strategy.dart';

/// Validation result model
class ValidationResult {
  ValidationResult({
    required this.isValid,
    this.errors = const [],
  });

  final bool isValid;
  final List<String> errors;

  /// Create a successful validation result
  factory ValidationResult.success() => ValidationResult(isValid: true);

  /// Create a failed validation result with errors
  factory ValidationResult.failure(List<String> errors) => 
      ValidationResult(isValid: false, errors: errors);
}

/// Base validation strategy interface
abstract class ValidationStrategy<T> extends SyncStrategy<T, ValidationResult> {
  @override
  String get identifier;

  @override
  bool canHandle(T input) => true; // Most validation strategies can handle any input

  /// Get validation rules for this strategy
  List<ValidationRule<T>> get rules;
}

/// Async wrapper for validation strategies
class AsyncValidationStrategy<T> extends Strategy<dynamic, ValidationResult> {
  AsyncValidationStrategy(this.syncStrategy);

  final ValidationStrategy<T> syncStrategy;

  @override
  String get identifier => syncStrategy.identifier;

  @override
  bool canHandle(dynamic input) {
    if (input is! T) return false;
    return syncStrategy.canHandle(input as T);
  }

  @override
  Future<ValidationResult> execute(dynamic input) async {
    if (input is! T) {
      return ValidationResult.failure(['Invalid input type for ${syncStrategy.identifier}']);
    }
    return syncStrategy.execute(input as T);
  }
}

/// Validation rule interface
abstract class ValidationRule<T> {
  String get fieldName;
  String? validate(T input);
}

/// Email validation rule
class EmailValidationRule implements ValidationRule<String> {
  @override
  String get fieldName => 'email';

  @override
  String? validate(String input) {
    if (input.isEmpty) return 'Email is required';
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(input)) {
      return 'Invalid email format';
    }
    return null;
  }
}

/// Password validation rule
class PasswordValidationRule implements ValidationRule<String> {
  @override
  String get fieldName => 'password';

  @override
  String? validate(String input) {
    if (input.isEmpty) return 'Password is required';
    if (input.length < 8) return 'Password must be at least 8 characters';
    if (!RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)').hasMatch(input)) {
      return 'Password must contain uppercase, lowercase, and number';
    }
    return null;
  }
}

/// Phone validation rule
class PhoneValidationRule implements ValidationRule<String> {
  @override
  String get fieldName => 'phone';

  @override
  String? validate(String input) {
    if (input.isEmpty) return 'Phone number is required';
    if (!RegExp(r'^\+?[\d\s\-\(\)]{10,}$').hasMatch(input)) {
      return 'Invalid phone number format';
    }
    return null;
  }
}

/// Required field validation rule
class RequiredFieldValidationRule<T> implements ValidationRule<T> {
  RequiredFieldValidationRule(this.fieldName);

  @override
  final String fieldName;

  @override
  String? validate(T input) {
    if (input == null) return '$fieldName is required';
    if (input is String && input.isEmpty) return '$fieldName is required';
    return null;
  }
}

/// String length validation rule
class StringLengthValidationRule implements ValidationRule<String> {
  StringLengthValidationRule({
    required this.fieldName,
    this.minLength = 0,
    this.maxLength = double.infinity,
  });

  @override
  final String fieldName;
  final int minLength;
  final double maxLength;

  @override
  String? validate(String input) {
    if (input.length < minLength) {
      return '$fieldName must be at least $minLength characters';
    }
    if (input.length > maxLength) {
      return '$fieldName must be no more than ${maxLength.toInt()} characters';
    }
    return null;
  }
}

/// Email validation strategy
class EmailValidationStrategy extends ValidationStrategy<String> {
  @override
  String get identifier => 'email';

  @override
  List<ValidationRule<String>> get rules => [
    RequiredFieldValidationRule<String>('email'),
    EmailValidationRule(),
  ];

  @override
  ValidationResult execute(String input) {
    final errors = <String>[];
    
    for (final rule in rules) {
      final error = rule.validate(input);
      if (error != null) {
        errors.add(error);
      }
    }

    return errors.isEmpty 
        ? ValidationResult.success()
        : ValidationResult.failure(errors);
  }
}

/// Password validation strategy
class PasswordValidationStrategy extends ValidationStrategy<String> {
  @override
  String get identifier => 'password';

  @override
  List<ValidationRule<String>> get rules => [
    RequiredFieldValidationRule<String>('password'),
    PasswordValidationRule(),
  ];

  @override
  ValidationResult execute(String input) {
    final errors = <String>[];
    
    for (final rule in rules) {
      final error = rule.validate(input);
      if (error != null) {
        errors.add(error);
      }
    }

    return errors.isEmpty 
        ? ValidationResult.success()
        : ValidationResult.failure(errors);
  }
}

/// Phone validation strategy
class PhoneValidationStrategy extends ValidationStrategy<String> {
  @override
  String get identifier => 'phone';

  @override
  List<ValidationRule<String>> get rules => [
    RequiredFieldValidationRule<String>('phone'),
    PhoneValidationRule(),
  ];

  @override
  ValidationResult execute(String input) {
    final errors = <String>[];
    
    for (final rule in rules) {
      final error = rule.validate(input);
      if (error != null) {
        errors.add(error);
      }
    }

    return errors.isEmpty 
        ? ValidationResult.success()
        : ValidationResult.failure(errors);
  }
}

/// User registration validation strategy
class UserRegistrationValidationStrategy extends ValidationStrategy<Map<String, dynamic>> {
  @override
  String get identifier => 'user_registration';

  @override
  List<ValidationRule<Map<String, dynamic>>> get rules => [
    _RequiredFieldRule('name'),
    _RequiredFieldRule('email'),
    _RequiredFieldRule('password'),
    _RequiredFieldRule('phone'),
  ];

  @override
  ValidationResult execute(Map<String, dynamic> input) {
    final errors = <String>[];
    
    // Validate email
    final emailResult = EmailValidationStrategy().execute(input['email']?.toString() ?? '');
    if (!emailResult.isValid) {
      errors.addAll(emailResult.errors);
    }

    // Validate password
    final passwordResult = PasswordValidationStrategy().execute(input['password']?.toString() ?? '');
    if (!passwordResult.isValid) {
      errors.addAll(passwordResult.errors);
    }

    // Validate phone
    final phoneResult = PhoneValidationStrategy().execute(input['phone']?.toString() ?? '');
    if (!phoneResult.isValid) {
      errors.addAll(phoneResult.errors);
    }

    // Validate name
    final nameResult = StringLengthValidationRule(
      fieldName: 'name',
      minLength: 2,
      maxLength: 50,
    ).validate(input['name']?.toString() ?? '');
    if (nameResult != null) {
      errors.add(nameResult);
    }

    return errors.isEmpty 
        ? ValidationResult.success()
        : ValidationResult.failure(errors);
  }
}

/// Helper class for required field validation in maps
class _RequiredFieldRule implements ValidationRule<Map<String, dynamic>> {
  _RequiredFieldRule(this.fieldName);

  @override
  final String fieldName;

  @override
  String? validate(Map<String, dynamic> input) {
    if (!input.containsKey(fieldName) || input[fieldName] == null) {
      return '$fieldName is required';
    }
    if (input[fieldName] is String && (input[fieldName] as String).isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }
}

/// Validation context for managing validation strategies
class ValidationContext {
  ValidationContext({
    required this.defaultStrategy,
    this.strategies = const [],
  });

  final Strategy<dynamic, ValidationResult> defaultStrategy;
  final List<Strategy<dynamic, ValidationResult>> strategies;

  /// Validate data using the appropriate strategy
  Future<ValidationResult> validate<T>(T data, {String? strategyId}) async {
    final strategy = strategyId != null 
        ? _getStrategyById(strategyId)
        : _selectStrategy(data);
    return await strategy.execute(data);
  }

  /// Select validation strategy based on data type
  Strategy<dynamic, ValidationResult> _selectStrategy(dynamic data) {
    for (final strategy in strategies) {
      if (strategy.canHandle(data)) {
        return strategy;
      }
    }
    return defaultStrategy;
  }

  /// Get strategy by identifier
  Strategy<dynamic, ValidationResult> _getStrategyById(String id) {
    return strategies.firstWhere(
      (s) => s.identifier == id,
      orElse: () => defaultStrategy,
    );
  }

  /// Add a validation strategy
  void addStrategy(Strategy<dynamic, ValidationResult> strategy) {
    strategies.add(strategy);
  }
}
