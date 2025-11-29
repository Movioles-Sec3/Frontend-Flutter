import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../core/result.dart';
import '../domain/entities/product.dart';
import '../domain/usecases/search_products_usecase.dart';
import '../services/cart_service.dart';
import '../widgets/offline_notice.dart';
import '../services/search_history_service.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  static const Duration _debounceDuration = Duration(milliseconds: 350);

  final TextEditingController _controller = TextEditingController();
  final SearchProductsUseCase _searchProductsUseCase = GetIt.I
      .get<SearchProductsUseCase>();
  late final SearchHistoryService _searchHistoryService;

  Timer? _debounce;
  bool _isLoading = false;
  bool _includeUnavailable = false;
  String? _error;
  List<ProductEntity> _results = <ProductEntity>[];
  List<String> _history = <String>[];

  @override
  void initState() {
    super.initState();
    _searchHistoryService = GetIt.I.get<SearchHistoryService>();
    _history = _searchHistoryService.history;
    _searchHistoryService.addListener(_onHistoryChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchHistoryService.removeListener(_onHistoryChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(_debounceDuration, () => _search(value));
  }

  void _onHistoryChanged() {
    if (!mounted) return;
    setState(() {
      _history = _searchHistoryService.history;
    });
  }

  Future<void> _search(String rawQuery) async {
    final String query = rawQuery.trim();
    if (query.isEmpty) {
      setState(() {
        _results = <ProductEntity>[];
        _error = null;
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    Result<List<ProductEntity>> result;
    try {
      result = await _searchProductsUseCase(
        query: query,
        includeUnavailable: _includeUnavailable,
        limit: 20,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error =
            'You appear to be offline. Try again once you regain connectivity.';
        _results = <ProductEntity>[];
        _isLoading = false;
      });
      return;
    }

    if (!mounted) return;

    if (result.isSuccess) {
      final List<ProductEntity> items = result.data ?? <ProductEntity>[];
      setState(() {
        _results = items;
        _isLoading = false;
      });
      await _searchHistoryService.addQuery(query);
    } else {
      String errorMessage = result.error ?? 'We could not complete the search.';
      final String normalized = errorMessage.toLowerCase();
      final bool offline =
          normalized.contains('network') ||
          normalized.contains('socketexception') ||
          normalized.contains('internet');

      if (offline && mounted) {
        final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(
          context,
        );
        messenger?.showSnackBar(
          const SnackBar(
            content: Text('You are offline. Try again once you reconnect.'),
            duration: Duration(seconds: 3),
          ),
        );
        errorMessage = 'You are offline. Try again once you reconnect.';
      }

      setState(() {
        _error = errorMessage;
        _results = <ProductEntity>[];
        _isLoading = false;
      });
    }
  }

  void _toggleIncludeUnavailable(bool value) {
    setState(() {
      _includeUnavailable = value;
    });
    _search(_controller.text);
  }

  void _addToCart(ProductEntity product) {
    CartService.instance.addOrIncrement(
      productId: product.id,
      name: product.name,
      imageUrl: product.imageUrl,
      unitPrice: product.price,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${product.name} added to cart'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool hasQuery = _controller.text.trim().isNotEmpty;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: <Widget>[
            const OfflineNotice(),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              onChanged: _onQueryChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search products...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _controller.text.isNotEmpty
                    ? IconButton(
                        onPressed: () {
                          _controller.clear();
                          _search('');
                        },
                        icon: const Icon(Icons.close),
                        tooltip: 'Limpiar búsqueda',
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              value: _includeUnavailable,
              onChanged: _toggleIncludeUnavailable,
              title: const Text('Show unavailable products'),
              contentPadding: EdgeInsets.zero,
            ),
            if (_history.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              _buildHistorySection(theme),
            ],
            const SizedBox(height: 12),
            if (_isLoading) const LinearProgressIndicator(),
            const SizedBox(height: 12),
            Expanded(child: _buildResults(theme, hasQuery)),
          ],
        ),
      ),
    );
  }

  Widget _buildResults(ThemeData theme, bool hasQuery) {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.error_outline, color: theme.colorScheme.error, size: 40),
            const SizedBox(height: 12),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => _search(_controller.text),
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      );
    }

    if (_results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.travel_explore_outlined,
                size: 48,
                color: theme.colorScheme.primary.withOpacity(0.6),
              ),
              const SizedBox(height: 12),
              Text(
                hasQuery
                    ? 'No products match your search.'
                    : 'Type a product name to start searching.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      itemCount: _results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (BuildContext context, int index) {
        final ProductEntity product = _results[index];
        return _ProductResultTile(
          product: product,
          onAddToCart: () => _addToCart(product),
        );
      },
    );
  }
}

class _ProductResultTile extends StatelessWidget {
  const _ProductResultTile({required this.product, required this.onAddToCart});

  final ProductEntity product;
  final VoidCallback onAddToCart;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isAvailable = product.available;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: _ProductThumbnail(imageUrl: product.imageUrl),
        title: Text(product.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              product.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            Text(
              '\$${product.price.toStringAsFixed(2)}',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (!isAvailable)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Chip(
                  visualDensity: VisualDensity.compact,
                  label: const Text('Unavailable'),
                ),
              ),
          ],
        ),
        isThreeLine: true,
        trailing: IconButton(
          onPressed: isAvailable ? onAddToCart : null,
          icon: const Icon(Icons.add_shopping_cart_outlined),
          tooltip: isAvailable ? 'Add to cart' : 'Product unavailable',
        ),
      ),
    );
  }
}

class _ProductThumbnail extends StatelessWidget {
  const _ProductThumbnail({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) {
      return const _FallbackThumbnail();
    }

    if (imageUrl.startsWith('http')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          cacheKey: 'img:product:$imageUrl',
          width: 56,
          height: 56,
          fit: BoxFit.cover,
          placeholder: (_, __) => Container(
            width: 56,
            height: 56,
            color: Colors.black12,
            child: const Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
          errorWidget: (_, __, ___) => const _FallbackThumbnail(),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.asset(imageUrl, width: 56, height: 56, fit: BoxFit.cover),
    );
  }
}

class _FallbackThumbnail extends StatelessWidget {
  const _FallbackThumbnail();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.local_bar_outlined,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

extension on _SearchPageState {
  Widget _buildHistorySection(ThemeData theme) {
    if (_history.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(
              'Recent searches',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            TextButton(
              onPressed: _history.isEmpty ? null : _clearHistory,
              child: const Text('Clear'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _history.map((String query) {
            return ActionChip(
              label: Text(query),
              onPressed: () {
                _controller.text = query;
                _controller.selection = TextSelection.fromPosition(
                  TextPosition(offset: _controller.text.length),
                );
                _search(query);
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Future<void> _clearHistory() async {
    await _searchHistoryService.clear();
  }
}
