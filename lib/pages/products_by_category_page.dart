import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/cart_service.dart';
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
  List<ProductEntity> _products = <ProductEntity>[];
  late final ErrorHandlingContext _errorHandlingContext;

  @override
  void initState() {
    super.initState();
    _errorHandlingContext = injector.get<ErrorHandlingContext>();
    _load();
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
        setState(() {
          _products = cached
              .map(
                (m) => ProductEntity(
                  id: (m['id'] as num?)?.toInt() ?? 0,
                  typeId:
                      (m['typeId'] as num?)?.toInt() ??
                      (m['id_tipo'] as num?)?.toInt() ??
                      0,
                  name: (m['name'] ?? m['nombre'] ?? '').toString(),
                  description: (m['description'] ?? m['descripcion'] ?? '')
                      .toString(),
                  imageUrl:
                      (m['imageUrl'] ?? m['imagen_url'] ?? m['imagen'] ?? '')
                          .toString(),
                  price: ((m['price'] ?? m['precio'] ?? 0) as num).toDouble(),
                  available:
                      (m['available'] ?? m['disponible'] ?? true) as bool,
                ),
              )
              .toList(growable: false);
          _loading = false;
        });
      }
    } catch (_) {}

    try {
      final GetProductsByCategoryUseCase useCase = GetIt.I
          .get<GetProductsByCategoryUseCase>();
      final Result<List<ProductEntity>> result = await useCase(
        widget.categoryId,
      );

      if (!mounted) return;

      if (result.isSuccess) {
        final items = result.data!;
        setState(() {
          _products = items;
          _loading = false;
        });
        // Persist to local cache for quick reopen
        final raw = items
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.categoryName)),
      body: Column(
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: OfflineNotice(),
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
    if (_products.isNotEmpty) {
      return ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: _products.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (BuildContext context, int index) {
          final ProductEntity p = _products[index];
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
                                      placeholder: (_, __) =>
                                          Container(color: Colors.black12),
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
