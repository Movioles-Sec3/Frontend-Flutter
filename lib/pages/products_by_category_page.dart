import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import '../services/cart_service.dart';
import '../core/result.dart';
import '../domain/entities/product.dart';
import '../domain/usecases/get_products_by_category_usecase.dart';

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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final GetProductsByCategoryUseCase useCase = GetIt.I
        .get<GetProductsByCategoryUseCase>();
    final Result<List<ProductEntity>> result = await useCase(widget.categoryId);

    if (!mounted) return;

    if (result.isSuccess) {
      setState(() {
        _products = result.data!;
        _loading = false;
      });
    } else {
      setState(() {
        _error = result.error;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.categoryName)),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
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

    if (_products.isEmpty) {
      return const Center(child: Text('No products found.'));
    }

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

        return Card(
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
                      : Image.network(
                          imagenUrl,
                          width: 110,
                          height: 90,
                          fit: BoxFit.cover,
                        ),
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
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Added to cart'),
                                      ),
                                    );
                                  }
                                : null,
                            icon: const Icon(Icons.add_shopping_cart_outlined),
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
        );
      },
    );
  }
}
