class CurrencyConversions {
  CurrencyConversions({
    required this.usd,
    required this.eur,
    required this.mxn,
  });

  final double usd;
  final double eur;
  final double mxn;

  factory CurrencyConversions.fromJson(Map<String, dynamic> json) {
    return CurrencyConversions(
      usd: ((json['USD'] ?? 0) as num).toDouble(),
      eur: ((json['EUR'] ?? 0) as num).toDouble(),
      mxn: ((json['MXN'] ?? 0) as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'USD': usd,
    'EUR': eur,
    'MXN': mxn,
  };
}

class ProductPriceConversion {
  ProductPriceConversion({
    required this.id,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.originalPrice,
    required this.originalCurrency,
    required this.conversions,
    required this.lastUpdated,
  });

  final int id;
  final String name;
  final String description;
  final String imageUrl;
  final double originalPrice;
  final String originalCurrency;
  final CurrencyConversions conversions;
  final DateTime lastUpdated;

  factory ProductPriceConversion.fromJson(Map<String, dynamic> json) {
    return ProductPriceConversion(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: (json['nombre'] ?? '').toString(),
      description: (json['descripcion'] ?? '').toString(),
      imageUrl: (json['imagen_url'] ?? '').toString(),
      originalPrice: ((json['precio_original'] ?? 0) as num).toDouble(),
      originalCurrency: (json['moneda_original'] ?? 'COP').toString(),
      conversions: CurrencyConversions.fromJson(json['conversiones'] ?? {}),
      lastUpdated: DateTime.tryParse(json['fecha_actualizacion']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'nombre': name,
    'descripcion': description,
    'imagen_url': imageUrl,
    'precio_original': originalPrice,
    'moneda_original': originalCurrency,
    'conversiones': conversions.toJson(),
    'fecha_actualizacion': lastUpdated.toIso8601String(),
  };

  /// Get price in specific currency
  double getPriceInCurrency(String currency) {
    switch (currency.toUpperCase()) {
      case 'USD':
        return conversions.usd;
      case 'EUR':
        return conversions.eur;
      case 'MXN':
        return conversions.mxn;
      case 'COP':
        return originalPrice;
      default:
        return originalPrice;
    }
  }

  /// Get currency symbol
  String getCurrencySymbol(String currency) {
    switch (currency.toUpperCase()) {
      case 'USD':
        return '\$';
      case 'EUR':
        return '€';
      case 'MXN':
        return '\$';
      case 'COP':
        return '\$';
      default:
        return '\$';
    }
  }

  /// Format price with currency
  String formatPrice(String currency) {
    final price = getPriceInCurrency(currency);
    final symbol = getCurrencySymbol(currency);
    
    if (currency.toUpperCase() == 'COP') {
      return '$symbol${price.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (Match m) => '${m[1]},',
      )}';
    } else {
      return '$symbol${price.toStringAsFixed(2)}';
    }
  }

  /// Get all available currencies
  List<String> get availableCurrencies => ['COP', 'USD', 'EUR', 'MXN'];
}

