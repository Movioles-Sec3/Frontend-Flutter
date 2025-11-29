import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/cart_service.dart';
import '../services/product_order_stats.dart';
import '../core/result.dart';
import '../domain/entities/product.dart';
import '../domain/usecases/get_products_by_category_usecase.dart';
import '../core/strategies/error_handling_strategy.dart';
import '../di/injector.dart';
import '../services/image_cache_manager.dart';
import '../services/local_catalog_storage.dart';
import '../widgets/offline_notice.dart';
import 'product_page.dart';

class ProductsByCategoryPage extends StatefulWidget {
  const ProductsByCategoryPage({
    super.key,
    required this.categoryId,
    required this.categoryName,
  });

  final int categoryId;
  final String categoryName;

  @override
  State<ProductsByCategoryPage> createState() => _ProductsByCategoryPageState();
}

class _ProductsByCategoryPageState extends State<ProductsByCategoryPage> {
  bool _loading = true;
  String? _error;
  List<ProductEntity> _filteredProducts = <ProductEntity>[];
  List<ProductEntity> _products = <ProductEntity>[];

  // Filter and sort state
  double _minPrice = 0;
  double _maxPrice = 1000;
  double _currentMinPrice = 0;
  double _currentMaxPrice = 1000;
  String _sortBy = 'most_ordered'; // 'most_ordered', 'price_low', 'price_high', 'name'
  Map<int, int> _orderCounts = {};
  late final ErrorHandlingContext _errorHandlingContext;

  @override
  void initState() {
    super.initState();
    _loadOrderStats();
    _errorHandlingContext = injector.get<ErrorHandlingContext>();
    _load();
  }
  Future<void> _loadOrderStats() async {
    final counts = await ProductOrderStats.instance.getOrderCounts();
    if (mounted) {
      setState(() {
        _orderCounts = counts;
      });
    }
  }


  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    // Fast path: try cached page first
    try {
      final cached = await LocalCatalogStorage.instance.readCategoryPage(
        categoryId: widget.categoryId,
        page: 1,
      );
      if (cached.isNotEmpty && mounted) {
        final List<ProductEntity> mapped = cached
            .map((m) => ProductEntity.fromJson(Map<String, dynamic>.from(m)))
            .where((p) => p.typeId == widget.categoryId)
            .toList(growable: false);
        if (mapped.isNotEmpty) {
          setState(() {
            _products = mapped;
            _loading = false;
          });
        }
      }
    } catch (_) {}

    try {
      final GetProductsByCategoryUseCase useCase = GetIt.I
          .get<GetProductsByCategoryUseCase>();
      final Result<List<ProductEntity>> result = await useCase(
        widget.categoryId,
        forceRefresh: true,
      );

      if (!mounted) return;

      if (result.isSuccess) {
        final List<ProductEntity> items = result.data!
            .where((p) => p.typeId == widget.categoryId)
            .toList(growable: false);

        // Calculate price range
        if (items.isNotEmpty) {
          final prices = items.map((p) => p.price).toList();
          _minPrice = prices.reduce((a, b) => a < b ? a : b);
          _maxPrice = prices.reduce((a, b) => a > b ? a : b);
          _currentMinPrice = _minPrice;
          _currentMaxPrice = _maxPrice;
        }

        setState(() {
          _products = items;
          _loading = false;
          _applyFiltersAndSort();
        });
        // Persist to local cache for quick reopen
        final List<ProductEntity> cacheSubset = items
            .take(_cacheLimitPerCategory)
            .toList(growable: false);
        final raw = cacheSubset
            .map(
              (p) => <String, dynamic>{
                'id': p.id,
                'id_tipo': p.typeId,
                'name': p.name,
                'description': p.description,
                'imageUrl': p.imageUrl,
                'price': p.price,
                'available': p.available,
              },
            )
            .toList(growable: false);
        // ignore: discarded_futures
        LocalCatalogStorage.instance.saveCategoryPage(
          categoryId: widget.categoryId,
          page: 1,
          products: raw,
        );
      } else {
        String friendly = result.error ?? 'Unable to load products';
        try {
          final handled = await _errorHandlingContext.handleError(
            Exception(result.error ?? 'Unknown error'),
          );
          friendly = handled.userMessage;
        } catch (_) {}
        setState(() {
          _error = friendly;
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      String friendly = 'Unable to load products';
      try {
        final handled = await _errorHandlingContext.handleError(
          e is Exception ? e : Exception(e.toString()),
        );
        friendly = handled.userMessage;
      } catch (_) {}
      setState(() {
        _error = friendly;
        _loading = false;
      });
    }
  }

  static const int _cacheLimitPerCategory = 20;

  void _applyFiltersAndSort() {
    // Filter by price
    var filtered = _products.where((p) =>
      p.price >= _currentMinPrice && p.price <= _currentMaxPrice
    ).toList();

    // Sort by selected criteria
    switch (_sortBy) {
      case 'most_ordered':
        filtered.sort((a, b) {
          final countA = _orderCounts[a.id] ?? 0;
          final countB = _orderCounts[b.id] ?? 0;
          if (countA != countB) {
            return countB.compareTo(countA); // Descending
          }
          return a.name.compareTo(b.name); // Alphabetical tie-breaker
        });
        break;
      case 'price_low':
        filtered.sort((a, b) => a.price.compareTo(b.price));
        break;
      case 'price_high':
        filtered.sort((a, b) => b.price.compareTo(a.price));
        break;
      case 'name':
        filtered.sort((a, b) => a.name.compareTo(b.name));
        break;
    }

    setState(() {
      _filteredProducts = filtered;
    });
  }

  void _showFilterOptions() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Filter & Sort',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Sort options
                Text(
                  'Sort By',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Most Ordered'),
                      selected: _sortBy == 'most_ordered',
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _sortBy = 'most_ordered');
                          setModalState(() => _sortBy = 'most_ordered');
                          _applyFiltersAndSort();
                        }
                      },
                    ),
                    ChoiceChip(
                      label: const Text('Price: Low to High'),
                      selected: _sortBy == 'price_low',
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _sortBy = 'price_low');
                          setModalState(() => _sortBy = 'price_low');
                          _applyFiltersAndSort();
                        }
                      },
                    ),
                    ChoiceChip(
                      label: const Text('Price: High to Low'),
                      selected: _sortBy == 'price_high',
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _sortBy = 'price_high');
                          setModalState(() => _sortBy = 'price_high');
                          _applyFiltersAndSort();
                        }
                      },
                    ),
                    ChoiceChip(
                      label: const Text('Name'),
                      selected: _sortBy == 'name',
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _sortBy = 'name');
                          setModalState(() => _sortBy = 'name');
                          _applyFiltersAndSort();
                        }
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Price range filter
                Text(
                  'Price Range',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  '\$${_currentMinPrice.toStringAsFixed(2)} - \$${_currentMaxPrice.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                RangeSlider(
                  values: RangeValues(_currentMinPrice, _currentMaxPrice),
                  min: _minPrice,
                  max: _maxPrice,
                  divisions: (_maxPrice - _minPrice > 1)
                      ? (_maxPrice - _minPrice).round()
                      : 10,
                  labels: RangeLabels(
                    '\$${_currentMinPrice.toStringAsFixed(0)}',
                    '\$${_currentMaxPrice.toStringAsFixed(0)}',
                  ),
                  onChanged: (values) {
                    setState(() {
                      _currentMinPrice = values.start;
                      _currentMaxPrice = values.end;
                    });
                    setModalState(() {
                      _currentMinPrice = values.start;
                      _currentMaxPrice = values.end;
                    });
                    _applyFiltersAndSort();
                  },
                ),

                const SizedBox(height: 16),

                // Reset button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _currentMinPrice = _minPrice;
                        _currentMaxPrice = _maxPrice;
                        _sortBy = 'most_ordered';
                      });
                      setModalState(() {
                        _currentMinPrice = _minPrice;
                        _currentMaxPrice = _maxPrice;
                        _sortBy = 'most_ordered';
                      });
                      _applyFiltersAndSort();
                    },
                    child: const Text('Reset Filters'),
                  ),
                ),

                const SizedBox(height: 8),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasActiveFilters = _currentMinPrice != _minPrice ||
                            _currentMaxPrice != _maxPrice ||
                            _sortBy != 'most_ordered';

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.categoryName),
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.filter_list),
                onPressed: _showFilterOptions,
                tooltip: 'Filter & Sort',
              ),
              if (hasActiveFilters)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: OfflineNotice(),
          ),
          if (_products.isNotEmpty && hasActiveFilters)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Showing ${_filteredProducts.length} of ${_products.length} products',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  TextButton(
                    onPressed: _showFilterOptions,
                    child: const Text('Adjust'),
                  ),
                ],
              ),
            ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    // If we have products, prefer showing them even if there was an error later
    if (_filteredProducts.isNotEmpty) {
      return ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: _filteredProducts.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        // Memory optimizations
        cacheExtent: 100,
        addAutomaticKeepAlives: false,
        addRepaintBoundaries: true,
        itemBuilder: (BuildContext context, int index) {
          final ProductEntity p = _filteredProducts[index];
          final String nombre = p.name;
          final String descripcion = p.description;
          final String imagenUrl = p.imageUrl;
          final double precio = p.price;
          final bool disponible = p.available;

          return InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ProductPage(product: p),
                ),
              );
            },
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: <Widget>[
                    SizedBox(
                      width: 110,
                      height: 90,
                      child: imagenUrl.isEmpty
                          ? Container(
                              color: Colors.grey[300],
                              child: const Icon(Icons.image_outlined),
                            )
                          : (imagenUrl.startsWith('http')
                                ? Hero(
                                    tag: 'product-${p.id}',
                                    child: CachedNetworkImage(
                                      imageUrl: imagenUrl,
                                      cacheKey: 'img:product:$imagenUrl',
                                      cacheManager:
                                          AppImageCacheManagers.productImages,
                                      width: 110,
                                      height: 90,
                                      fit: BoxFit.cover,
                                      memCacheWidth: 256,
                                      memCacheHeight: 210,
                                      // Faster fade-in to reduce animation CPU
                                      fadeInDuration: const Duration(milliseconds: 200),
                                      placeholderFadeInDuration: const Duration(milliseconds: 100),
                                      // Simplified placeholder to reduce rasterization
                                      placeholder: (_, __) =>
                                          const ColoredBox(color: Color(0xFFE0E0E0)),
                                      errorWidget: (_, __, ___) =>
                                          const Icon(Icons.broken_image),
                                    ),
                                  )
                                : Hero(
                                    tag: 'product-${p.id}',
                                    child: Image.asset(
                                      imagenUrl,
                                      width: 110,
                                      height: 90,
                                      fit: BoxFit.cover,
                                      cacheWidth: 220, // Optimize asset decoding
                                      cacheHeight: 180,
                                    ),
                                  )),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            nombre,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            descripcion,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: <Widget>[
                              Text(
                                '\$${precio.toStringAsFixed(2)}',
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              const Spacer(),
                              IconButton(
                                tooltip: 'Add to cart',
                                onPressed: disponible
                                    ? () {
                                        CartService.instance.addOrIncrement(
                                          productId: p.id,
                                          name: nombre,
                                          imageUrl: imagenUrl,
                                          unitPrice: precio,
                                        );
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text('Added to cart'),
                                          ),
                                        );
                                      }
                                    : null,
                                icon: const Icon(
                                  Icons.add_shopping_cart_outlined,
                                ),
                              ),
                            ],
                          ),
                          if (!disponible)
                            const Padding(
                              padding: EdgeInsets.only(top: 4),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Chip(
                                  label: Text('Unavailable'),
                                  visualDensity: VisualDensity.compact,
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    }

    // Show message if products exist but filters exclude all
    if (_products.isNotEmpty && _filteredProducts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.filter_list_off,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'No products match your filters',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Try adjusting the price range or sort options',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _showFilterOptions,
                icon: const Icon(Icons.tune),
                label: const Text('Adjust Filters'),
              ),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    // Empty state
    return const Center(child: Text('No products found.'));
  }
}
