import 'strategy.dart';
import '../../domain/entities/product_price_conversion.dart';

/// Currency display request
class CurrencyDisplayRequest {
  CurrencyDisplayRequest({
    required this.productPriceConversion,
    required this.preferredCurrencies,
    this.showOriginalPrice = true,
    this.maxCurrencies = 4,
  });

  final ProductPriceConversion productPriceConversion;
  final List<String> preferredCurrencies;
  final bool showOriginalPrice;
  final int maxCurrencies;
}

/// Currency display result
class CurrencyDisplayResult {
  CurrencyDisplayResult({
    required this.success,
    this.displayedCurrencies,
    this.error,
    this.strategy,
  });

  final bool success;
  final List<CurrencyDisplay>? displayedCurrencies;
  final String? error;
  final String? strategy;

  factory CurrencyDisplayResult.success(List<CurrencyDisplay> currencies, String strategy) => 
      CurrencyDisplayResult(success: true, displayedCurrencies: currencies, strategy: strategy);
  factory CurrencyDisplayResult.failure(String error) => 
      CurrencyDisplayResult(success: false, error: error);
}

/// Currency display information
class CurrencyDisplay {
  CurrencyDisplay({
    required this.currency,
    required this.symbol,
    required this.price,
    required this.formattedPrice,
    required this.isOriginal,
  });

  final String currency;
  final String symbol;
  final double price;
  final String formattedPrice;
  final bool isOriginal;
}

/// Base currency display strategy interface
abstract class CurrencyDisplayStrategy extends Strategy<CurrencyDisplayRequest, CurrencyDisplayResult> {
  @override
  String get identifier;

  @override
  bool canHandle(CurrencyDisplayRequest input) => true;
}

/// All currencies display strategy
class AllCurrenciesDisplayStrategy extends CurrencyDisplayStrategy {
  @override
  String get identifier => 'all_currencies';

  @override
  Future<CurrencyDisplayResult> execute(CurrencyDisplayRequest input) async {
    try {
      final currencies = <CurrencyDisplay>[];
      
      // Add original currency if requested
      if (input.showOriginalPrice) {
        currencies.add(CurrencyDisplay(
          currency: input.productPriceConversion.originalCurrency,
          symbol: input.productPriceConversion.getCurrencySymbol(input.productPriceConversion.originalCurrency),
          price: input.productPriceConversion.originalPrice,
          formattedPrice: input.productPriceConversion.formatPrice(input.productPriceConversion.originalCurrency),
          isOriginal: true,
        ));
      }

      // Add converted currencies
      for (final currency in input.productPriceConversion.availableCurrencies) {
        if (currency != input.productPriceConversion.originalCurrency) {
          currencies.add(CurrencyDisplay(
            currency: currency,
            symbol: input.productPriceConversion.getCurrencySymbol(currency),
            price: input.productPriceConversion.getPriceInCurrency(currency),
            formattedPrice: input.productPriceConversion.formatPrice(currency),
            isOriginal: false,
          ));
        }
      }

      // Limit to max currencies
      final limitedCurrencies = currencies.take(input.maxCurrencies).toList();

      return CurrencyDisplayResult.success(limitedCurrencies, identifier);
    } catch (e) {
      return CurrencyDisplayResult.failure('All currencies display failed: $e');
    }
  }
}

/// Preferred currencies display strategy
class PreferredCurrenciesDisplayStrategy extends CurrencyDisplayStrategy {
  @override
  String get identifier => 'preferred_currencies';

  @override
  Future<CurrencyDisplayResult> execute(CurrencyDisplayRequest input) async {
    try {
      final currencies = <CurrencyDisplay>[];
      
      // Add original currency if requested and in preferred list
      if (input.showOriginalPrice && 
          input.preferredCurrencies.contains(input.productPriceConversion.originalCurrency)) {
        currencies.add(CurrencyDisplay(
          currency: input.productPriceConversion.originalCurrency,
          symbol: input.productPriceConversion.getCurrencySymbol(input.productPriceConversion.originalCurrency),
          price: input.productPriceConversion.originalPrice,
          formattedPrice: input.productPriceConversion.formatPrice(input.productPriceConversion.originalCurrency),
          isOriginal: true,
        ));
      }

      // Add preferred currencies
      for (final currency in input.preferredCurrencies) {
        if (currency != input.productPriceConversion.originalCurrency && 
            input.productPriceConversion.availableCurrencies.contains(currency)) {
          currencies.add(CurrencyDisplay(
            currency: currency,
            symbol: input.productPriceConversion.getCurrencySymbol(currency),
            price: input.productPriceConversion.getPriceInCurrency(currency),
            formattedPrice: input.productPriceConversion.formatPrice(currency),
            isOriginal: false,
          ));
        }
      }

      // Limit to max currencies
      final limitedCurrencies = currencies.take(input.maxCurrencies).toList();

      return CurrencyDisplayResult.success(limitedCurrencies, identifier);
    } catch (e) {
      return CurrencyDisplayResult.failure('Preferred currencies display failed: $e');
    }
  }
}

/// International focus strategy (USD, EUR, MXN)
class InternationalFocusDisplayStrategy extends CurrencyDisplayStrategy {
  @override
  String get identifier => 'international_focus';

  @override
  Future<CurrencyDisplayResult> execute(CurrencyDisplayRequest input) async {
    try {
      final currencies = <CurrencyDisplay>[];
      final internationalCurrencies = ['USD', 'EUR', 'MXN'];
      
      // Add original currency if it's not international
      if (input.showOriginalPrice && 
          !internationalCurrencies.contains(input.productPriceConversion.originalCurrency)) {
        currencies.add(CurrencyDisplay(
          currency: input.productPriceConversion.originalCurrency,
          symbol: input.productPriceConversion.getCurrencySymbol(input.productPriceConversion.originalCurrency),
          price: input.productPriceConversion.originalPrice,
          formattedPrice: input.productPriceConversion.formatPrice(input.productPriceConversion.originalCurrency),
          isOriginal: true,
        ));
      }

      // Add international currencies
      for (final currency in internationalCurrencies) {
        if (input.productPriceConversion.availableCurrencies.contains(currency)) {
          currencies.add(CurrencyDisplay(
            currency: currency,
            symbol: input.productPriceConversion.getCurrencySymbol(currency),
            price: input.productPriceConversion.getPriceInCurrency(currency),
            formattedPrice: input.productPriceConversion.formatPrice(currency),
            isOriginal: currency == input.productPriceConversion.originalCurrency,
          ));
        }
      }

      // Limit to max currencies
      final limitedCurrencies = currencies.take(input.maxCurrencies).toList();

      return CurrencyDisplayResult.success(limitedCurrencies, identifier);
    } catch (e) {
      return CurrencyDisplayResult.failure('International focus display failed: $e');
    }
  }
}

/// Compact display strategy (shows only 2-3 currencies)
class CompactDisplayStrategy extends CurrencyDisplayStrategy {
  @override
  String get identifier => 'compact';

  @override
  Future<CurrencyDisplayResult> execute(CurrencyDisplayRequest input) async {
    try {
      final currencies = <CurrencyDisplay>[];
      
      // Always show original currency
      currencies.add(CurrencyDisplay(
        currency: input.productPriceConversion.originalCurrency,
        symbol: input.productPriceConversion.getCurrencySymbol(input.productPriceConversion.originalCurrency),
        price: input.productPriceConversion.originalPrice,
        formattedPrice: input.productPriceConversion.formatPrice(input.productPriceConversion.originalCurrency),
        isOriginal: true,
      ));

      // Add one international currency (prefer USD)
      final preferredInternational = ['USD', 'EUR', 'MXN'];
      for (final currency in preferredInternational) {
        if (input.productPriceConversion.availableCurrencies.contains(currency) && 
            currency != input.productPriceConversion.originalCurrency) {
          currencies.add(CurrencyDisplay(
            currency: currency,
            symbol: input.productPriceConversion.getCurrencySymbol(currency),
            price: input.productPriceConversion.getPriceInCurrency(currency),
            formattedPrice: input.productPriceConversion.formatPrice(currency),
            isOriginal: false,
          ));
          break; // Only add one international currency
        }
      }

      return CurrencyDisplayResult.success(currencies, identifier);
    } catch (e) {
      return CurrencyDisplayResult.failure('Compact display failed: $e');
    }
  }
}

/// Currency display context for managing currency display strategies
class CurrencyDisplayContext {
  CurrencyDisplayContext({
    required this.defaultStrategy,
    this.strategies = const [],
  });

  final CurrencyDisplayStrategy defaultStrategy;
  final List<CurrencyDisplayStrategy> strategies;

  /// Get currency display using the appropriate strategy
  Future<CurrencyDisplayResult> getCurrencyDisplay(CurrencyDisplayRequest request) async {
    final strategy = _selectStrategy(request);
    return await strategy.execute(request);
  }

  /// Select currency display strategy based on request
  CurrencyDisplayStrategy _selectStrategy(CurrencyDisplayRequest request) {
    for (final strategy in strategies) {
      if (strategy.canHandle(request)) {
        return strategy;
      }
    }
    return defaultStrategy;
  }

  /// Add a currency display strategy
  void addStrategy(CurrencyDisplayStrategy strategy) {
    strategies.add(strategy);
  }

  /// Get available currency display strategies
  List<String> getAvailableStrategies() {
    return strategies.map((s) => s.identifier).toList();
  }
}

