import 'strategy.dart';

/// Payment data model
class PaymentData {
  PaymentData({
    required this.amount,
    required this.currency,
    required this.orderId,
    this.paymentMethodId,
    this.metadata = const {},
  });

  final double amount;
  final String currency;
  final String orderId;
  final String? paymentMethodId;
  final Map<String, dynamic> metadata;
}

/// Payment result model
class PaymentResult {
  PaymentResult({
    required this.success,
    required this.transactionId,
    this.errorMessage,
    this.paymentMethod,
  });

  final bool success;
  final String transactionId;
  final String? errorMessage;
  final String? paymentMethod;
}

/// Base payment strategy interface
abstract class PaymentStrategy extends Strategy<PaymentData, PaymentResult> {
  @override
  String get identifier;

  @override
  bool canHandle(PaymentData input) {
    return input.paymentMethodId == identifier;
  }

  /// Validate payment data before processing
  Future<bool> validatePayment(PaymentData data);
}

/// Credit card payment strategy
class CreditCardPaymentStrategy extends PaymentStrategy {
  @override
  String get identifier => 'credit_card';

  @override
  Future<PaymentResult> execute(PaymentData input) async {
    try {
      // Simulate credit card processing
      await Future.delayed(const Duration(seconds: 2));
      
      // Mock validation - in real app, this would call payment gateway
      final isValid = await validatePayment(input);
      if (!isValid) {
        return PaymentResult(
          success: false,
          transactionId: '',
          errorMessage: 'Invalid credit card information',
          paymentMethod: identifier,
        );
      }

      return PaymentResult(
        success: true,
        transactionId: 'CC_${DateTime.now().millisecondsSinceEpoch}',
        paymentMethod: identifier,
      );
    } catch (e) {
      return PaymentResult(
        success: false,
        transactionId: '',
        errorMessage: 'Credit card payment failed: $e',
        paymentMethod: identifier,
      );
    }
  }

  @override
  Future<bool> validatePayment(PaymentData data) async {
    // Mock validation logic
    return data.amount > 0 && data.currency.isNotEmpty;
  }
}

/// PayPal payment strategy
class PayPalPaymentStrategy extends PaymentStrategy {
  @override
  String get identifier => 'paypal';

  @override
  Future<PaymentResult> execute(PaymentData input) async {
    try {
      // Simulate PayPal processing
      await Future.delayed(const Duration(seconds: 3));
      
      final isValid = await validatePayment(input);
      if (!isValid) {
        return PaymentResult(
          success: false,
          transactionId: '',
          errorMessage: 'PayPal payment validation failed',
          paymentMethod: identifier,
        );
      }

      return PaymentResult(
        success: true,
        transactionId: 'PP_${DateTime.now().millisecondsSinceEpoch}',
        paymentMethod: identifier,
      );
    } catch (e) {
      return PaymentResult(
        success: false,
        transactionId: '',
        errorMessage: 'PayPal payment failed: $e',
        paymentMethod: identifier,
      );
    }
  }

  @override
  Future<bool> validatePayment(PaymentData data) async {
    // Mock PayPal validation
    return data.amount > 0 && data.currency.isNotEmpty;
  }
}

/// Cash payment strategy
class CashPaymentStrategy extends PaymentStrategy {
  @override
  String get identifier => 'cash';

  @override
  Future<PaymentResult> execute(PaymentData input) async {
    try {
      // Cash payments are always successful (for pickup orders)
      await Future.delayed(const Duration(milliseconds: 500));
      
      return PaymentResult(
        success: true,
        transactionId: 'CASH_${DateTime.now().millisecondsSinceEpoch}',
        paymentMethod: identifier,
      );
    } catch (e) {
      return PaymentResult(
        success: false,
        transactionId: '',
        errorMessage: 'Cash payment processing failed: $e',
        paymentMethod: identifier,
      );
    }
  }

  @override
  Future<bool> validatePayment(PaymentData data) async {
    // Cash payments don't need validation
    return true;
  }
}

/// Payment context for managing payment strategies
class PaymentContext {
  PaymentContext({
    required this.defaultStrategy,
    this.strategies = const [],
  });

  final PaymentStrategy defaultStrategy;
  final List<PaymentStrategy> strategies;

  /// Process payment using the appropriate strategy
  Future<PaymentResult> processPayment(PaymentData data) async {
    final strategy = _selectStrategy(data);
    return await strategy.execute(data);
  }

  /// Select payment strategy based on payment method
  PaymentStrategy _selectStrategy(PaymentData data) {
    for (final strategy in strategies) {
      if (strategy.canHandle(data)) {
        return strategy;
      }
    }
    return defaultStrategy;
  }

  /// Add a payment strategy
  void addStrategy(PaymentStrategy strategy) {
    strategies.add(strategy);
  }

  /// Get available payment methods
  List<String> getAvailablePaymentMethods() {
    return strategies.map((s) => s.identifier).toList();
  }
}
