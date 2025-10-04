import 'package:flutter/material.dart';
import 'package:flutter_tapandtoast/pages/order_pickup_page.dart';
import 'package:intl/intl.dart';
import 'package:get_it/get_it.dart';
import '../services/cart_service.dart';
import '../core/result.dart';
import '../domain/entities/order.dart';
import '../domain/usecases/create_order_usecase.dart';

class CartItem {
  final int productId;
  final String name;
  final int quantity;
  final double unitPrice;
  final String image; // puede ser network o asset

  const CartItem({
    required this.productId,
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.image,
  });

  double get lineTotal => unitPrice * quantity;
}

class OrderSummaryPage extends StatelessWidget {
  final List<CartItem> items;

  const OrderSummaryPage({super.key, required this.items});

  String _money(double v) => NumberFormat.simpleCurrency().format(v);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text('Order Summary'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: CartService.instance,
          builder: (BuildContext context, Widget? _) {
            final List<CartItemData> data = CartService.instance.items;
            final double subtotal = data.fold<double>(
              0,
              (double s, CartItemData e) => s + e.lineTotal,
            );
            final double total = subtotal;

            return ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                const Text(
                  'Products',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                if (data.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: Text('Your cart is empty')),
                  )
                else
                  ...data.map(
                    (CartItemData e) => _EditableProductTile(item: e),
                  ),
                const SizedBox(height: 16),
                const Divider(height: 32),
                const Text(
                  'Total',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                _RowKV(label: 'Subtotal', value: _money(subtotal)),
                const SizedBox(height: 4),
                const Divider(),
                _RowKV(label: 'Total', value: _money(total), isBold: true),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: data.isEmpty
                      ? null
                      : () async {
                          final CreateOrderUseCase useCase = GetIt.I
                              .get<CreateOrderUseCase>();
                          final Result<OrderEntity> result = await useCase(
                            CartService.instance.toOrderProductosPayload(),
                          );

                          if (!context.mounted) return;

                          if (result.isSuccess) {
                            CartService.instance.clear();
                            final OrderEntity order = result.data!;
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute<OrderPickupPage>(
                                builder: (_) => OrderPickupPage(
                                  order:
                                      order.raw ??
                                      <String, dynamic>{
                                        'id': order.id,
                                        'total': order.total,
                                        'estado': order.status,
                                        'fecha_hora': order.placedAt,
                                        'fecha_listo': order.readyAt ?? '',
                                        'fecha_entregado':
                                            order.deliveredAt ?? '',
                                        if (order.qr != null) 'qr': order.qr,
                                      },
                                ),
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(result.error!)),
                            );
                          }
                        },
                  child: const Text('Confirm Order'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _EditableProductTile extends StatelessWidget {
  final CartItemData item;
  const _EditableProductTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final Widget image = item.imageUrl.startsWith('http')
        ? Image.network(item.imageUrl, fit: BoxFit.cover)
        : Image.asset(item.imageUrl, fit: BoxFit.cover);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(width: 56, height: 56, child: image),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  item.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '\$${item.unitPrice.toStringAsFixed(2)} · x${item.quantity} = \$${item.lineTotal.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Row(
            children: <Widget>[
              IconButton(
                tooltip: 'Decrease',
                onPressed: () =>
                    CartService.instance.decrementOrRemove(item.productId),
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Text('${item.quantity}'),
              IconButton(
                tooltip: 'Increase',
                onPressed: () => CartService.instance.addOrIncrement(
                  productId: item.productId,
                  name: item.name,
                  imageUrl: item.imageUrl,
                  unitPrice: item.unitPrice,
                ),
                icon: const Icon(Icons.add_circle_outline),
              ),
              IconButton(
                tooltip: 'Remove',
                onPressed: () => CartService.instance.remove(item.productId),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RowKV extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;
  const _RowKV({required this.label, required this.value, this.isBold = false});

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: 15,
      fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value, style: style),
        ],
      ),
    );
  }
}
