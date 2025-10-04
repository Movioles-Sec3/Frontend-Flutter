import 'package:flutter/material.dart';
import '../core/strategies/currency_strategy.dart';
import '../domain/entities/product_price_conversion.dart';
import '../domain/usecases/get_product_price_conversion_usecase.dart';
import '../di/injector.dart';

class PriceDisplayWidget extends StatefulWidget {
  const PriceDisplayWidget({
    super.key,
    required this.productId,
    this.title = 'Price',
    this.displayStyle = 'international_focus',
    this.showTitle = true,
    this.compact = false,
  });

  final int productId;
  final String title;
  final String displayStyle; // 'all_currencies', 'preferred_currencies', 'international_focus', 'compact'
  final bool showTitle;
  final bool compact;

  @override
  State<PriceDisplayWidget> createState() => _PriceDisplayWidgetState();
}

class _PriceDisplayWidgetState extends State<PriceDisplayWidget> {
  late final CurrencyDisplayContext _currencyDisplayContext;
  late final GetProductPriceConversionUseCase _getPriceConversionUseCase;

  ProductPriceConversion? _productPriceConversion;
  List<CurrencyDisplay>? _displayedCurrencies;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _currencyDisplayContext = injector.get<CurrencyDisplayContext>();
    _getPriceConversionUseCase = injector.get<GetProductPriceConversionUseCase>();
    _loadPriceConversions();
  }

  Future<void> _loadPriceConversions() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await _getPriceConversionUseCase(widget.productId);

      if (result.isSuccess && result.data != null) {
        _productPriceConversion = result.data!;
        await _formatCurrencyDisplay();
      } else {
        setState(() {
          _error = result.error ?? 'Failed to load price conversions';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error loading price conversions: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _formatCurrencyDisplay() async {
    if (_productPriceConversion == null) return;

    try {
      final request = CurrencyDisplayRequest(
        productPriceConversion: _productPriceConversion!,
        preferredCurrencies: ['USD', 'EUR', 'MXN'],
        showOriginalPrice: true,
        maxCurrencies: widget.compact ? 2 : 4,
      );

      final result = await _currencyDisplayContext.getCurrencyDisplay(request);

      if (result.success && result.displayedCurrencies != null) {
        setState(() {
          _displayedCurrencies = result.displayedCurrencies!;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = result.error ?? 'Failed to format currency display';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error formatting currency display: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.showTitle) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          _buildPriceDisplay(),
        ],
      );
    }

    return _buildPriceDisplay();
  }

  Widget _buildPriceDisplay() {
    if (_isLoading) {
      return const SizedBox(
        height: 40,
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              Icons.error_outline,
              color: Theme.of(context).colorScheme.onErrorContainer,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _error!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                  fontSize: 12,
                ),
              ),
            ),
            IconButton(
              onPressed: _loadPriceConversions,
              icon: Icon(
                Icons.refresh,
                color: Theme.of(context).colorScheme.onErrorContainer,
                size: 16,
              ),
            ),
          ],
        ),
      );
    }

    if (_displayedCurrencies == null || _displayedCurrencies!.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          'No price information available',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    if (widget.compact) {
      return _buildCompactPriceDisplay();
    } else {
      return _buildFullPriceDisplay();
    }
  }

  Widget _buildCompactPriceDisplay() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: _displayedCurrencies!.map((currency) {
          return Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  currency.formattedPrice,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: currency.isOriginal ? FontWeight.bold : FontWeight.normal,
                    color: currency.isOriginal 
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                Text(
                  currency.currency,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFullPriceDisplay() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Price Information',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (_productPriceConversion != null)
                Text(
                  'Updated ${_formatLastUpdated()}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Currency prices
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: _displayedCurrencies!.map((currency) {
              return _buildCurrencyCard(currency);
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrencyCard(CurrencyDisplay currency) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: currency.isOriginal 
            ? Theme.of(context).colorScheme.primaryContainer
            : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: currency.isOriginal 
            ? Border.all(color: Theme.of(context).colorScheme.primary)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                currency.symbol,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: currency.isOriginal 
                      ? Theme.of(context).colorScheme.onPrimaryContainer
                      : Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                currency.formattedPrice.replaceFirst(currency.symbol, ''),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: currency.isOriginal 
                      ? Theme.of(context).colorScheme.onPrimaryContainer
                      : Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            currency.currency,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: currency.isOriginal 
                  ? Theme.of(context).colorScheme.onPrimaryContainer
                  : Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (currency.isOriginal)
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'ORIGINAL',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatLastUpdated() {
    if (_productPriceConversion == null) return '';
    
    final now = DateTime.now();
    final difference = now.difference(_productPriceConversion!.lastUpdated);
    
    if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}

