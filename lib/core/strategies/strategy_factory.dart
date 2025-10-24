import 'package:flutter_tapandtoast/core/strategies/strategy.dart';
import 'package:path_provider/path_provider.dart';
import '../../domain/usecases/get_recommended_products_usecase.dart';
import 'caching_strategy.dart';
import 'currency_strategy.dart';
import 'error_handling_strategy.dart';
import 'payment_strategy.dart';
import 'recommendation_strategy.dart';
import 'ui_strategy.dart';
import 'validation_strategy.dart';

/// Strategy factory for creating and managing all strategy instances
class StrategyFactory {
  static bool _initialized = false;
  static final Map<String, List<Strategy<dynamic, dynamic>>> _strategies = {};

  /// Initialize all strategies
  static Future<void> initialize() async {
    if (_initialized) return;

    // Initialize payment strategies
    _initializePaymentStrategies();

    // Initialize validation strategies
    _initializeValidationStrategies();

    // Initialize caching strategies
    await _initializeCachingStrategies();

    // Initialize UI strategies
    _initializeUIStrategies();

    // Initialize error handling strategies
    _initializeErrorHandlingStrategies();

    // Initialize recommendation strategies
    _initializeRecommendationStrategies();

    // Initialize currency strategies
    _initializeCurrencyStrategies();

    _initialized = true;
  }

  /// Initialize payment strategies
  static void _initializePaymentStrategies() {
    // Register payment strategies
    StrategyFactory.register<PaymentData, PaymentResult>(
      CreditCardPaymentStrategy(),
    );
    StrategyFactory.register<PaymentData, PaymentResult>(
      PayPalPaymentStrategy(),
    );
    StrategyFactory.register<PaymentData, PaymentResult>(
      CashPaymentStrategy(),
    );
  }

  /// Initialize validation strategies
  static void _initializeValidationStrategies() {
    // Register validation strategies with async wrappers using dynamic input type
    StrategyFactory.register<dynamic, ValidationResult>(
      AsyncValidationStrategy<String>(EmailValidationStrategy()),
    );
    StrategyFactory.register<dynamic, ValidationResult>(
      AsyncValidationStrategy<String>(PasswordValidationStrategy()),
    );
    StrategyFactory.register<dynamic, ValidationResult>(
      AsyncValidationStrategy<String>(PhoneValidationStrategy()),
    );
    StrategyFactory.register<dynamic, ValidationResult>(
      AsyncValidationStrategy<Map<String, dynamic>>(UserRegistrationValidationStrategy()),
    );
  }

  /// Initialize caching strategies
  static Future<void> _initializeCachingStrategies() async {
    // Get cache directory
    final cacheDir = await getApplicationDocumentsDirectory();
    final cachePath = '${cacheDir.path}/app_cache';

    // Register caching strategies
    StrategyFactory.register<String, CacheResult<String>>(
      MemoryCachingStrategy<String>(maxSize: 100),
    );
    StrategyFactory.register<String, CacheResult<String>>(
      FileCachingStrategy<String>(
        cacheDirectory: cachePath,
        serializer: (data) => data,
        deserializer: (data) => data,
      ),
    );
    StrategyFactory.register<String, CacheResult<String>>(
      HybridCachingStrategy<String>(
        memoryStrategy: MemoryCachingStrategy<String>(maxSize: 100),
        fileStrategy: FileCachingStrategy<String>(
          cacheDirectory: cachePath,
          serializer: (data) => data,
          deserializer: (data) => data,
        ),
      ),
    );
  }

  /// Initialize UI strategies
  static void _initializeUIStrategies() {
    // Register UI strategies
    StrategyFactory.register<UIThemeData, UIRenderingResult>(
      MaterialUIStrategy(),
    );
    StrategyFactory.register<UIThemeData, UIRenderingResult>(
      CupertinoUIStrategy(),
    );
  }

  /// Initialize error handling strategies
  static void _initializeErrorHandlingStrategies() {
    // Register error handling strategies
    StrategyFactory.register<Exception, ErrorHandlingResult>(
      NetworkErrorHandlingStrategy(),
    );
    StrategyFactory.register<Exception, ErrorHandlingResult>(
      AuthenticationErrorHandlingStrategy(),
    );
    StrategyFactory.register<Exception, ErrorHandlingResult>(
      ValidationErrorHandlingStrategy(),
    );
    StrategyFactory.register<Exception, ErrorHandlingResult>(
      ServerErrorHandlingStrategy(),
    );
    StrategyFactory.register<Exception, ErrorHandlingResult>(
      DefaultErrorHandlingStrategy(),
    );
  }

  /// Initialize recommendation strategies
  static void _initializeRecommendationStrategies() {
    // Note: Recommendation strategies will be registered in createRecommendationContext
    // because they need the use case dependency
  }

  /// Initialize currency strategies
  static void _initializeCurrencyStrategies() {
    // Register currency display strategies
    StrategyFactory.register<CurrencyDisplayRequest, CurrencyDisplayResult>(
      AllCurrenciesDisplayStrategy(),
    );
    StrategyFactory.register<CurrencyDisplayRequest, CurrencyDisplayResult>(
      PreferredCurrenciesDisplayStrategy(),
    );
    StrategyFactory.register<CurrencyDisplayRequest, CurrencyDisplayResult>(
      InternationalFocusDisplayStrategy(),
    );
    StrategyFactory.register<CurrencyDisplayRequest, CurrencyDisplayResult>(
      CompactDisplayStrategy(),
    );
  }

  /// Create payment context
  static PaymentContext createPaymentContext() {
    final strategies = StrategyFactory.getStrategies<PaymentData, PaymentResult>()
        .cast<PaymentStrategy>();
    
    return PaymentContext(
      defaultStrategy: strategies.firstWhere(
        (s) => s.identifier == 'credit_card',
        orElse: () => CreditCardPaymentStrategy(),
      ),
      strategies: strategies,
    );
  }

  /// Create validation context
  static ValidationContext createValidationContext() {
    final strategies = StrategyFactory.getStrategies<dynamic, ValidationResult>()
        .cast<Strategy<dynamic, ValidationResult>>();
    
    return ValidationContext(
      defaultStrategy: strategies.firstWhere(
        (s) => s.identifier == 'email',
        orElse: () => AsyncValidationStrategy<String>(EmailValidationStrategy()),
      ),
      strategies: strategies,
    );
  }

  /// Create cache context
  static CacheContext<String> createCacheContext() {
    final strategies = StrategyFactory.getStrategies<String, CacheResult<String>>()
        .cast<CachingStrategy<String>>();
    
    return CacheContext<String>(
      defaultStrategy: strategies.firstWhere(
        (s) => s.identifier == 'hybrid',
        orElse: () => MemoryCachingStrategy<String>(),
      ),
      strategies: strategies,
    );
  }

  /// Create UI context
  static UIContext createUIContext() {
    final strategies = StrategyFactory.getStrategies<UIThemeData, UIRenderingResult>()
        .cast<UIStrategy>();
    
    return UIContext(
      defaultStrategy: strategies.firstWhere(
        (s) => s.identifier == 'material',
        orElse: () => MaterialUIStrategy(),
      ),
      strategies: strategies,
    );
  }

  /// Create error handling context
  static ErrorHandlingContext createErrorHandlingContext() {
    final strategies = StrategyFactory.getStrategies<Exception, ErrorHandlingResult>()
        .cast<ErrorHandlingStrategy>();
    
    return ErrorHandlingContext(
      defaultStrategy: strategies.firstWhere(
        (s) => s.identifier == 'default',
        orElse: () => DefaultErrorHandlingStrategy(),
      ),
      strategies: strategies,
    );
  }

  /// Create recommendation context
  static RecommendationContext createRecommendationContext(GetRecommendedProductsUseCase useCase) {
    final popularityStrategy = PopularityRecommendationStrategy(useCase);
    final categoryStrategy = CategoryRecommendationStrategy(useCase);
    final mixedStrategy = MixedRecommendationStrategy(
      popularityStrategy: popularityStrategy,
      categoryStrategy: categoryStrategy,
    );

    return RecommendationContext(
      defaultStrategy: popularityStrategy,
      strategies: [popularityStrategy, categoryStrategy, mixedStrategy],
    );
  }

  /// Create currency display context
  static CurrencyDisplayContext createCurrencyDisplayContext() {
    final strategies = StrategyFactory.getStrategies<CurrencyDisplayRequest, CurrencyDisplayResult>()
        .cast<CurrencyDisplayStrategy>();
    
    return CurrencyDisplayContext(
      defaultStrategy: strategies.firstWhere(
        (s) => s.identifier == 'international_focus',
        orElse: () => InternationalFocusDisplayStrategy(),
      ),
      strategies: strategies,
    );
  }

  /// Get all registered strategies for a type
  static List<Strategy<T, R>> getStrategies<T, R>() {
    final key = _getTypeKey<T, R>();
    return _strategies[key]?.cast<Strategy<T, R>>() ?? [];
  }

  /// Register a strategy
  static void register<T, R>(Strategy<T, R> strategy) {
    final key = _getTypeKey<T, R>();
    _strategies.putIfAbsent(key, () => []);
    _strategies[key]!.add(strategy);
  }

  /// Generate a unique key for type combination
  static String _getTypeKey<T, R>() {
    return '${T.toString()}_${R.toString()}';
  }

  /// Create a strategy context
  static StrategyContext<T, R> createContext<T, R>({
    required Strategy<T, R> defaultStrategy,
  }) {
    return StrategyContext<T, R>(
      defaultStrategy: defaultStrategy,
      strategies: getStrategies<T, R>(),
    );
  }
}
