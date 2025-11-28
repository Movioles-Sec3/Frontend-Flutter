import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../core/models/product_detail_data.dart';
import '../domain/entities/product.dart';
import '../services/cart_service.dart';
import '../services/image_cache_manager.dart';
import '../services/product_detail_cache.dart';
import '../services/product_local_storage.dart';
import '../widgets/offline_notice.dart';

class ProductPage extends StatefulWidget {
  const ProductPage({super.key, required this.product});

  final ProductEntity product;

  @override
  State<ProductPage> createState() => _ProductPageState();
}

class _ProductPageState extends State<ProductPage> {
  int _quantity = 1;
  late final Future<PreparedProductData> _preparedFuture;
  bool _prefetchedImage = false;
  late final ProductLocalStorage _productLocalStorage;

  @override
  void initState() {
    super.initState();
    _productLocalStorage = GetIt.I<ProductLocalStorage>();
    // Offload light formatting/normalization to an isolate and cache the result.
    _preparedFuture = _loadPrepared(widget.product);
  }

  Future<PreparedProductData> _loadPrepared(ProductEntity product) async {
    final PreparedProductData? cached =
        ProductDetailCache.instance.get(product.id);
    if (cached != null) return cached;

    final PreparedProductData? fromDisk =
        await _productLocalStorage.getProduct(
      product.id,
      maxAge: const Duration(hours: 12),
    );
    if (fromDisk != null) {
      ProductDetailCache.instance.put(fromDisk);
      return fromDisk;
    }

    final PreparedProductData data =
        await compute<ProductInput, PreparedProductData>(
      prepareProductData,
      ProductInput.fromEntity(product),
    );
    ProductDetailCache.instance.put(data);
    await _productLocalStorage.saveProduct(data);
    return data;
  }

  void _increment() => setState(() => _quantity = (_quantity + 1).clamp(1, 20));

  void _decrement() =>
      setState(() => _quantity = (_quantity - 1).clamp(1, 20));

  void _addToCart() {
    final product = widget.product;
    final CartService cart = CartService.instance;
    final int existing = cart.getQuantity(product.id);

    if (existing == 0) {
      cart.addOrIncrement(
        productId: product.id,
        name: product.name,
        imageUrl: product.imageUrl,
        unitPrice: product.price,
      );
      if (_quantity > 1) {
        cart.setQuantity(product.id, _quantity);
      }
    } else {
      cart.setQuantity(product.id, existing + _quantity);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${product.name} x$_quantity agregado al carrito',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return FutureBuilder<PreparedProductData>(
      future: _preparedFuture,
      builder: (BuildContext context, AsyncSnapshot<PreparedProductData> snap) {
        if (snap.hasError ||
            (snap.connectionState == ConnectionState.done && !snap.hasData)) {
          return Scaffold(
            backgroundColor: colors.surface,
            appBar: AppBar(
              title: Text(widget.product.name),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
            body: const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'No internet connection. Unable to load product details.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          );
        }

        if (snap.connectionState != ConnectionState.done) {
          return Scaffold(
            backgroundColor: colors.surface,
            appBar: AppBar(
              title: Text(widget.product.name),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final PreparedProductData data =
            snap.data ?? PreparedProductData.fromEntity(widget.product);
        _prefetchImage(context, data);

        return Scaffold(
          backgroundColor: colors.surface,
          appBar: AppBar(
            title: Text(data.name),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
          bottomNavigationBar: SafeArea(
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              decoration: BoxDecoration(
                color: colors.surface,
                border: Border(
                  top: BorderSide(color: colors.outline.withOpacity(0.2)),
                ),
              ),
              child: Row(
                children: [
                  _QtyControl(
                    quantity: _quantity,
                    onAdd: _increment,
                    onRemove: _decrement,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: data.available ? _addToCart : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colors.primary,
                          foregroundColor: colors.onPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          data.available
                              ? 'Agregar - \$${(data.price * _quantity).toStringAsFixed(2)}'
                              : 'No disponible',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: OfflineNotice(
                    message: 'No internet connection. Showing available data.',
                  ),
                ),
                _ProductHeader(product: widget.product, heroTag: data.heroTag),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Text(
                      '\$${data.price.toStringAsFixed(2)}',
                      style: textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colors.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Chip(
                      label: Text(data.available ? 'Disponible' : 'No disponible'),
                      backgroundColor: data.available
                          ? colors.primary.withOpacity(0.12)
                          : colors.error.withOpacity(0.12),
                      labelStyle: TextStyle(
                        color: data.available ? colors.primary : colors.error,
                      ),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  data.name,
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  data.description,
                  style: textTheme.bodyMedium?.copyWith(height: 1.45),
                ),
                const SizedBox(height: 24),
                _InfoCard(
                  title: 'Detalles del producto',
                  children: [
                    _InfoRow(label: 'ID', value: '#${data.id}'),
                    _InfoRow(label: 'Tipo', value: data.typeId.toString()),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _prefetchImage(BuildContext context, PreparedProductData data) {
    if (_prefetchedImage) return;
    _prefetchedImage = true;
    if (data.imageUrl.isEmpty || !data.imageUrl.startsWith('http')) return;
    final ImageProvider provider = CachedNetworkImageProvider(
      data.imageUrl,
      cacheKey: 'img:product:${data.id}:${data.imageUrl}',
      cacheManager: AppImageCacheManagers.productImages,
    );
    // ignore: discarded_futures
    precacheImage(provider, context);
  }
}

class _ProductHeader extends StatelessWidget {
  const _ProductHeader({required this.product, required this.heroTag});
  final ProductEntity product;
  final String heroTag;

  @override
  Widget build(BuildContext context) {
    final String imageUrl = product.imageUrl;
    final BorderRadius radius = BorderRadius.circular(18);
    final ColorScheme colors = Theme.of(context).colorScheme;

    Widget image;
    if (imageUrl.isEmpty) {
      image = Container(
        height: 260,
        decoration: BoxDecoration(
          borderRadius: radius,
          color: Colors.grey[200],
        ),
        child: const Center(
          child: Icon(Icons.image_not_supported_outlined, size: 50),
        ),
      );
    } else if (imageUrl.startsWith('http')) {
      image = CachedNetworkImage(
        imageUrl: imageUrl,
        cacheKey: 'img:product:${product.id}:$imageUrl',
        cacheManager: AppImageCacheManagers.productImages,
        imageBuilder: (_, ImageProvider provider) => Container(
          height: 260,
          decoration: BoxDecoration(
            borderRadius: radius,
            image: DecorationImage(
              image: provider,
              fit: BoxFit.cover,
            ),
          ),
        ),
        placeholder: (_, __) => Container(
          height: 260,
          decoration: BoxDecoration(
            borderRadius: radius,
            color: Colors.black12,
          ),
        ),
        errorWidget: (_, __, ___) => Container(
          height: 260,
          decoration: BoxDecoration(
            borderRadius: radius,
            color: Colors.grey[200],
          ),
          child: const Center(
            child: Icon(Icons.broken_image_outlined, size: 46),
          ),
        ),
      );
    } else {
      image = ClipRRect(
        borderRadius: radius,
        child: Image.asset(
          imageUrl,
          height: 260,
          width: double.infinity,
          fit: BoxFit.cover,
        ),
      );
    }

    return Stack(
      children: [
        Hero(
          tag: heroTag,
          child: image,
        ),
        Positioned(
          top: 12,
          right: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: colors.surface.withOpacity(0.9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.outline.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.local_offer_outlined, size: 16, color: colors.primary),
                const SizedBox(width: 6),
                Text(
                  'Tap & Toast',
                  style: TextStyle(
                    color: colors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _QtyControl extends StatelessWidget {
  const _QtyControl({
    required this.quantity,
    required this.onAdd,
    required this.onRemove,
  });

  final int quantity;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceVariant.withOpacity(0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outline.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.remove),
            splashRadius: 20,
          ),
          Text(
            quantity.toString(),
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          IconButton(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            splashRadius: 20,
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.outline.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(
            label,
            style: textTheme.bodyMedium?.copyWith(
              color: colors.onSurface.withOpacity(0.6),
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
