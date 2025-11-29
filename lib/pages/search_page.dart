import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../core/result.dart';
import '../domain/entities/product.dart';
import '../domain/usecases/search_products_usecase.dart';
import '../services/cart_service.dart';
import '../services/image_cache_manager.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final CartService _cartService = CartService.instance;

  Timer? _debounce;
  bool _isLoading = false;
  bool _onlyAvailable = true;
  String _query = '';
  String? _error;
  List<ProductEntity> _results = <ProductEntity>[];

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
    _controller.addListener(_onQueryChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller
      ..removeListener(_onQueryChanged)
      ..dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    final String next = _controller.text;
    if (next == _query) return;

    _query = next;
    _error = null;

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      _performSearch(_query);
    });
  }

  Future<void> _performSearch(String rawQuery) async {
    final String query = rawQuery.trim();
    if (query.isEmpty) {
      setState(() {
        _results = <ProductEntity>[];
        _isLoading = false;
        _error = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final SearchProductsUseCase useCase = GetIt.I.get<SearchProductsUseCase>();
    final Result<List<ProductEntity>> result = await useCase(
      query,
      available: _onlyAvailable ? true : null,
      limit: 30,
    );

    if (!mounted) return;

    if (result.isSuccess) {
      setState(() {
        _results = result.data ?? <ProductEntity>[];
        _isLoading = false;
      });
    } else {
      setState(() {
        _error = result.error ?? 'No se pudo completar la búsqueda.';
        _results = <ProductEntity>[];
        _isLoading = false;
      });
    }
  }

  void _toggleAvailability(bool value) {
    setState(() {
      _onlyAvailable = value;
    });
    _performSearch(_query);
  }

  void _addToCart(ProductEntity product) {
    _cartService.addOrIncrement(
      productId: product.id,
      name: product.name,
      imageUrl: product.imageUrl,
      unitPrice: product.price,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${product.name} agregado al carrito'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Buscar'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              textInputAction: TextInputAction.search,
              onSubmitted: _performSearch,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Busca por nombre (ej. mojito)',
                filled: true,
                fillColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest.withOpacity(0.6),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: <Widget>[
          SwitchListTile(
            value: _onlyAvailable,
            onChanged: _toggleAvailability,
            secondary: const Icon(Icons.check_circle_outline),
            title: const Text('Mostrar solo disponibles'),
          ),
          const Divider(height: 1),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_query.trim().isEmpty) {
      return _buildEmptyState(
        icon: Icons.search,
        message: 'Empieza a escribir para buscar productos.',
      );
    }

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _buildEmptyState(
        icon: Icons.error_outline,
        message: _error!,
        action: TextButton(
          onPressed: () => _performSearch(_query),
          child: const Text('Reintentar'),
        ),
      );
    }

    if (_results.isEmpty) {
      return _buildEmptyState(
        icon: Icons.inventory_2_outlined,
        message: 'No encontramos coincidencias con “$_query”.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (BuildContext context, int index) {
        final ProductEntity product = _results[index];
        return _SearchResultCard(
          product: product,
          onAddToCart: () => _addToCart(product),
        );
      },
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String message,
    Widget? action,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(icon, size: 56, color: Colors.grey.shade500),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
            ),
            if (action != null) ...<Widget>[const SizedBox(height: 12), action],
          ],
        ),
      ),
    );
  }
}

class _SearchResultCard extends StatelessWidget {
  const _SearchResultCard({required this.product, required this.onAddToCart});

  final ProductEntity product;
  final VoidCallback onAddToCart;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 80,
                height: 80,
                child: product.imageUrl.isEmpty
                    ? Container(
                        color: Colors.grey.shade300,
                        child: const Icon(Icons.local_drink_outlined),
                      )
                    : CachedNetworkImage(
                        imageUrl: product.imageUrl,
                        cacheKey:
                            'img:search:${product.id}:${product.imageUrl}',
                        cacheManager: AppImageCacheManagers.productImages,
                        fit: BoxFit.cover,
                        memCacheWidth: 240,
                        memCacheHeight: 240,
                        placeholder: (_, __) =>
                            Container(color: Colors.grey.shade200),
                        errorWidget: (_, __, ___) =>
                            const Icon(Icons.broken_image),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    product.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    product.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: <Widget>[
                      Text(
                        '\$${product.price.toStringAsFixed(0)}',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: product.available
                            ? 'Agregar al carrito'
                            : 'Producto no disponible',
                        onPressed: product.available ? onAddToCart : null,
                        icon: const Icon(Icons.add_shopping_cart_outlined),
                      ),
                    ],
                  ),
                  if (!product.available)
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Chip(
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        label: Text('No disponible'),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
