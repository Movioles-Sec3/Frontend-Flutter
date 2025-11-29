import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../core/result.dart';
import '../domain/entities/product.dart';
import '../domain/usecases/search_products_usecase.dart';
import '../services/cart_service.dart';
import '../services/search_favorites_db.dart';
import '../services/search_history_service.dart';
import '../services/local_catalog_storage.dart';
import '../widgets/offline_notice.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  static const Duration _debounceDuration = Duration(milliseconds: 350);
  static const int _localResultLimit = 40;

  final TextEditingController _controller = TextEditingController();
  final SearchProductsUseCase _searchProductsUseCase = GetIt.I
      .get<SearchProductsUseCase>();
  late final SearchHistoryService _searchHistoryService;
  final SearchFavoritesDb _favoritesDb = SearchFavoritesDb.instance;

  Timer? _debounce;
  bool _isLoading = false;
  bool _includeUnavailable = false;
  String? _error;
  List<ProductEntity> _results = <ProductEntity>[];
  List<String> _history = <String>[];
  final Set<int> _favoriteIds = <int>{};
  List<ProductEntity> _favoriteProducts = <ProductEntity>[];
  bool _favoritesLoading = false;
  bool _isSearchingLocally = false;

  @override
  void initState() {
    super.initState();
    _searchHistoryService = GetIt.I.get<SearchHistoryService>();
    _history = _searchHistoryService.history;
    _searchHistoryService.addListener(_onHistoryChanged);
    _refreshFavorites();
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
        _isSearchingLocally = false;
      });
      return;
    }

    setState(() {
      _error = null;
      _isSearchingLocally = true;
    });

    List<ProductEntity> localResults = <ProductEntity>[];
    try {
      localResults = await _searchLocal(query);
    } catch (_) {
      // Swallow local errors; remote search will handle the user feedback.
    }

    if (!mounted) return;

    setState(() {
      _results = localResults;
      _isSearchingLocally = false;
      _isLoading = true;
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
        _isLoading = false;
        if (_results.isEmpty) {
          _results = <ProductEntity>[];
        }
      });
      return;
    }

    if (!mounted) return;

    if (result.isSuccess) {
      final List<ProductEntity> items = result.data ?? <ProductEntity>[];
      setState(() {
        _results = items;
        _isLoading = false;
        _error = null;
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

      final bool hadResults = _results.isNotEmpty;

      setState(() {
        _error = errorMessage;
        _isLoading = false;
        if (!hadResults) {
          _results = <ProductEntity>[];
        }
      });
    }
  }

  Future<List<ProductEntity>> _searchLocal(String query) async {
    final List<Map<String, dynamic>> localProducts = await LocalCatalogStorage
        .instance
        .readAllProducts();
    if (localProducts.isEmpty) return <ProductEntity>[];

    final List<Map<String, dynamic>> filtered =
        await compute(_filterLocalProducts, <String, dynamic>{
          'products': localProducts,
          'query': query,
          'includeUnavailable': _includeUnavailable,
          'limit': _localResultLimit,
        });

    if (filtered.isEmpty) return <ProductEntity>[];

    return filtered.map(ProductEntity.fromJson).toList(growable: false);
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
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
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
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _openFavoritesPane,
                  tooltip: 'Ver favoritos',
                  icon: const Icon(Icons.star_outline),
                ),
              ],
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
            if (_isSearchingLocally)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: const <Widget>[
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 8),
                    Text('Buscando resultados locales...'),
                  ],
                ),
              ),
            if (_isLoading) const LinearProgressIndicator(),
            const SizedBox(height: 12),
            Expanded(child: _buildResults(theme, hasQuery)),
          ],
        ),
      ),
    );
  }

  Widget _buildResults(ThemeData theme, bool hasQuery) {
    final bool hasError = _error != null && _error!.isNotEmpty;

    if (hasError && _results.isEmpty) {
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
      itemCount: _results.length + (hasError ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (BuildContext context, int index) {
        if (hasError && index == 0) {
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.error_outline,
                  color: theme.colorScheme.onErrorContainer,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _error!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        final int productIndex = hasError ? index - 1 : index;
        final ProductEntity product = _results[productIndex];
        return _ProductResultTile(
          product: product,
          onAddToCart: () => _addToCart(product),
          isFavorite: _favoriteIds.contains(product.id),
          onToggleFavorite: () => _toggleFavorite(product),
        );
      },
    );
  }

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

  Future<void> _refreshFavorites() async {
    setState(() {
      _favoritesLoading = true;
    });
    final List<ProductEntity> favorites = await _favoritesDb.getFavorites();
    if (!mounted) return;
    setState(() {
      _favoriteProducts = favorites;
      _favoriteIds
        ..clear()
        ..addAll(favorites.map((ProductEntity e) => e.id));
      _favoritesLoading = false;
    });
  }

  Future<void> _toggleFavorite(ProductEntity product) async {
    final bool isFav = _favoriteIds.contains(product.id);
    if (isFav) {
      await _favoritesDb.removeFavorite(product.id);
    } else {
      await _favoritesDb.addFavorite(product);
    }
    if (!mounted) return;
    await _refreshFavorites();
  }

  Future<void> _openFavoritesPane() async {
    await _refreshFavorites();
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext ctx) {
        return SafeArea(
          child: FractionallySizedBox(
            heightFactor: 0.75,
            child: StatefulBuilder(
              builder: (BuildContext context, StateSetter setModalState) {
                Future<void> refetch() async {
                  await _refreshFavorites();
                  if (!context.mounted) return;
                  setModalState(() {});
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Text(
                            'Favorites',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const Spacer(),
                          if (_favoriteProducts.isNotEmpty)
                            TextButton(
                              onPressed: () async {
                                await _favoritesDb.clear();
                                if (!mounted) return;
                                await refetch();
                              },
                              child: const Text('Clear all'),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_favoritesLoading)
                        const Expanded(
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (_favoriteProducts.isEmpty)
                        Expanded(
                          child: Center(
                            child: Text(
                              'No favorites yet. Add some from the search results.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        )
                      else
                        Expanded(
                          child: ListView.separated(
                            itemCount: _favoriteProducts.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (BuildContext context, int index) {
                              final ProductEntity product =
                                  _favoriteProducts[index];
                              return _ProductResultTile(
                                product: product,
                                onAddToCart: () => _addToCart(product),
                                isFavorite: true,
                                onToggleFavorite: () async {
                                  await _toggleFavorite(product);
                                  if (!context.mounted) return;
                                  setModalState(() {});
                                },
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

List<Map<String, dynamic>> _filterLocalProducts(Map<String, dynamic> args) {
  final List<dynamic> rawProducts =
      args['products'] as List<dynamic>? ?? <dynamic>[];
  final String query = (args['query'] ?? '').toString().trim().toLowerCase();

  if (query.isEmpty || rawProducts.isEmpty) {
    return <Map<String, dynamic>>[];
  }

  final bool includeUnavailable = args['includeUnavailable'] as bool? ?? false;
  int limit = args['limit'] is int ? args['limit'] as int : 20;
  if (limit < 1) limit = 1;
  if (limit > 100) limit = 100;

  final List<Map<String, dynamic>> matches = <Map<String, dynamic>>[];

  for (final dynamic entry in rawProducts) {
    if (entry is! Map<String, dynamic>) continue;
    final Map<String, dynamic> product = entry;
    final String name = (product['name'] ?? product['nombre'] ?? '').toString();
    if (name.isEmpty) continue;

    final dynamic availabilityRaw =
        product['available'] ?? product['disponible'] ?? true;
    final bool available = availabilityRaw is bool
        ? availabilityRaw
        : availabilityRaw is num
        ? availabilityRaw != 0
        : availabilityRaw.toString().toLowerCase() == 'true';

    if (!includeUnavailable && !available) {
      continue;
    }

    if (name.toLowerCase().contains(query)) {
      matches.add(Map<String, dynamic>.from(product));
      if (matches.length >= limit) {
        break;
      }
    }
  }

  return matches;
}

class _ProductResultTile extends StatelessWidget {
  const _ProductResultTile({
    required this.product,
    required this.onAddToCart,
    required this.isFavorite,
    required this.onToggleFavorite,
  });

  final ProductEntity product;
  final VoidCallback onAddToCart;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;

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
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            IconButton(
              onPressed: onToggleFavorite,
              icon: Icon(
                isFavorite ? Icons.star : Icons.star_outline,
                color: isFavorite
                    ? theme.colorScheme.primary
                    : theme.iconTheme.color,
              ),
              tooltip: isFavorite
                  ? 'Remove from favorites'
                  : 'Add to favorites',
            ),
            IconButton(
              onPressed: isAvailable ? onAddToCart : null,
              icon: const Icon(Icons.add_shopping_cart_outlined),
              tooltip: isAvailable ? 'Add to cart' : 'Product unavailable',
            ),
          ],
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
