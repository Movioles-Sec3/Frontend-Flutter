# Strategy Pattern Architecture

This directory contains a comprehensive implementation of the Strategy pattern for the Flutter TapAndToast app. The Strategy pattern allows you to define a family of algorithms, encapsulate each one, and make them interchangeable at runtime.

## Architecture Overview

The strategy pattern implementation consists of several key components:

### Core Components

1. **Base Strategy Interface** (`strategy.dart`)
   - `Strategy<T, R>` - Base interface for async strategies
   - `SyncStrategy<T, R>` - Base interface for sync strategies
   - `StrategyContext<T, R>` - Context class for managing strategies
   - `StrategyFactory` - Factory for creating strategy instances

2. **Payment Strategies** (`payment_strategy.dart`)
   - `CreditCardPaymentStrategy` - Handles credit card payments
   - `PayPalPaymentStrategy` - Handles PayPal payments
   - `CashPaymentStrategy` - Handles cash payments
   - `PaymentContext` - Manages payment strategy selection

3. **Validation Strategies** (`validation_strategy.dart`)
   - `EmailValidationStrategy` - Validates email addresses
   - `PasswordValidationStrategy` - Validates passwords
   - `PhoneValidationStrategy` - Validates phone numbers
   - `UserRegistrationValidationStrategy` - Validates user registration data
   - `ValidationContext` - Manages validation strategy selection

4. **Caching Strategies** (`caching_strategy.dart`)
   - `MemoryCachingStrategy` - In-memory caching
   - `FileCachingStrategy` - File-based caching
   - `HybridCachingStrategy` - Combined memory and file caching
   - `CacheContext` - Manages caching strategy selection

5. **UI Strategies** (`ui_strategy.dart`)
   - `MaterialUIStrategy` - Material Design theming
   - `CupertinoUIStrategy` - Cupertino theming
   - `CustomUIStrategy` - Custom theming
   - `UIContext` - Manages UI strategy selection

6. **Strategy Factory** (`strategy_factory.dart`)
   - Centralized factory for creating and managing all strategies
   - Automatic strategy registration and context creation

## Usage Examples

### Payment Processing

```dart
// Get payment context from dependency injection
final paymentContext = injector.get<PaymentContext>();

// Create payment data
final paymentData = PaymentData(
  amount: 100.0,
  currency: 'USD',
  orderId: 'ORDER_123',
  paymentMethodId: 'credit_card',
);

// Process payment using appropriate strategy
final result = await paymentContext.processPayment(paymentData);
```

### Data Validation

```dart
// Get validation context from dependency injection
final validationContext = injector.get<ValidationContext>();

// Validate email
final emailResult = validationContext.validate('user@example.com', strategyId: 'email');

// Validate password
final passwordResult = validationContext.validate('password123', strategyId: 'password');
```

### Caching

```dart
// Get cache context from dependency injection
final cacheContext = injector.get<CacheContext<String>>();

// Store data in cache
await cacheContext.store('key', 'value', expiration: Duration(hours: 1));

// Retrieve data from cache
final result = await cacheContext.retrieve('key');
```

### UI Theming

```dart
// Get UI context from dependency injection
final uiContext = injector.get<UIContext>();

// Create themed widget
final themedWidget = uiContext.createThemedWidget(themeData, child);
```

## Benefits of This Implementation

1. **Flexibility**: Algorithms can be selected at runtime
2. **Extensibility**: New strategies can be added without modifying existing code
3. **Testability**: Each strategy can be tested independently
4. **Maintainability**: Changes to one strategy don't affect others
5. **Separation of Concerns**: Each strategy handles one specific responsibility
6. **Dependency Injection**: Strategies are managed through the DI container

## Adding New Strategies

To add a new strategy:

1. Create a new strategy class implementing the appropriate interface
2. Register it in the `StrategyFactory.initialize()` method
3. Add it to the dependency injection container if needed
4. Use it through the appropriate context class

Example:

```dart
class NewPaymentStrategy extends PaymentStrategy {
  @override
  String get identifier => 'new_payment';

  @override
  Future<PaymentResult> execute(PaymentData input) async {
    // Implementation
  }
}

// Register in StrategyFactory
StrategyFactory.register<PaymentData, PaymentResult>(NewPaymentStrategy());
```

## Integration with Existing Code

The strategy pattern is integrated into the existing app through:

1. **Dependency Injection**: All strategy contexts are registered in the DI container
2. **Service Layer**: The `StrategyCartService` demonstrates how to use strategies in services
3. **UI Layer**: The `StrategyDemoPage` shows how to use strategies in the UI
4. **Navigation**: A new "Strategies" tab has been added to demonstrate the functionality

## Demo Page

The `StrategyDemoPage` provides a comprehensive demonstration of all strategy implementations:

- **Validation Demo**: Test email and password validation
- **Payment Demo**: Test different payment methods
- **Cart Service Demo**: See how strategies are used in the cart service
- **Benefits Overview**: Learn about the advantages of the strategy pattern

## Future Enhancements

Potential areas for expansion:

1. **Database Strategies**: Different database implementations (SQLite, Firebase, etc.)
2. **Authentication Strategies**: Different auth methods (OAuth, JWT, etc.)
3. **Notification Strategies**: Different notification channels (push, email, SMS)
4. **Analytics Strategies**: Different analytics providers (Firebase, Mixpanel, etc.)
5. **Image Loading Strategies**: Different image loading libraries (cached_network_image, etc.)

This implementation provides a solid foundation for applying the strategy pattern throughout the Flutter app, making it more flexible, maintainable, and extensible.
