import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tapandtoast/core/strategies/caching_strategy.dart';
import 'package:flutter_tapandtoast/core/strategies/strategy_factory.dart';
import 'package:flutter_tapandtoast/pages/order_pickup_page.dart';
import 'package:intl/intl.dart';
import 'package:get_it/get_it.dart';
import '../services/cart_service.dart';
import '../core/result.dart';
import '../domain/entities/order.dart';
import '../domain/usecases/create_order_usecase.dart';
import '../services/exchange_rate_service.dart';
import '../services/local_orders_storage.dart';
import '../services/orders_db.dart';
import '../services/orders_sync_service.dart';
import '../services/connectivity_service.dart';

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
    // Ensure connectivity and sync services are initialized (idempotent)
    // ignore: discarded_futures
    ConnectivityService.instance.initialize();
    // ignore: discarded_futures
    OrdersSyncService.instance.start();
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
            final List<Map<String, num>> payload = data
                .map((CartItemData e) => <String, num>{
                      'price': e.unitPrice,
                      'qty': e.quantity,
                    })
                .toList(growable: false);

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
                FutureBuilder<double>(
                  future: _subtotalWithCache(payload),
                  builder: (BuildContext context, AsyncSnapshot<double> snap) {
                    final bool loading = !snap.hasData;
                    final double subtotal = snap.data ?? 0.0;
                    final double total = subtotal;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        _RowKV(
                          label: 'Subtotal',
                          value: loading ? '—' : _money(subtotal),
                        ),
                        const SizedBox(height: 4),
                        const Divider(),
                        _RowKV(
                          label: 'Total',
                          value: loading ? '—' : _money(total),
                          isBold: true,
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
                if (data.isNotEmpty)
                  FilledButton(
                    onPressed: () async {
                      final contextToUse = context;
                      final CartItemData reference = data.first;
                      final double subtotal = data.fold<double>(0, (s, e) => s + e.lineTotal);

                      showDialog(
                        context: contextToUse,
                        builder: (_) {
                          final Future<Map<String, double>> future = ExchangeRateService().getRates('COP');

                          String formatCop(double val) {
                            final price = val.toStringAsFixed(0).replaceAllMapped(
                              RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                              (Match m) => '${m[1]},',
                            );
                            return '\$${price}';
                          }

                          String formatMoney(double val, String symbol) => '$symbol${val.toStringAsFixed(2)}';

                          return AlertDialog(
                            title: const Text('Total in Other Currencies'),
                            content: FutureBuilder<Map<String, double>>(
                              future: future,
                              builder: (context, snapshot) {
                                if (!snapshot.hasData) {
                                  return const SizedBox(
                                    height: 80,
                                    child: Center(child: CircularProgressIndicator()),
                                  );
                                }
                                final Map<String, double> rates = snapshot.data!;
                                final double subtotalUsd = subtotal * (rates['USD'] ?? 0);
                                final double subtotalEur = subtotal * (rates['EUR'] ?? 0);
                                final double subtotalMxn = subtotal * (rates['MXN'] ?? 0);

                                return Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ListTile(
                                      leading: const Text('COP'),
                                      title: Text('${formatCop(subtotal)} (COP)'),
                                    ),
                                    ListTile(
                                      leading: const Text('USD'),
                                      title: Text('${formatMoney(subtotalUsd, '\$')} (USD)'),
                                    ),
                                    ListTile(
                                      leading: const Text('EUR'),
                                      title: Text('${formatMoney(subtotalEur, '€')} (EUR)'),
                                    ),
                                    ListTile(
                                      leading: const Text('MXN'),
                                      title: Text('${formatMoney(subtotalMxn, '\$')} (MXN)'),
                                    ),
                                  ],
                                );
                              },
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(contextToUse).pop(),
                                child: const Text('Close'),
                              ),
                            ],
                          );
                        },
                      );
                    },
                    child: const Text('See Conversion'),
                  ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: data.isEmpty
                      ? null
                      : () async {
                          final CreateOrderUseCase useCase = GetIt.I
                              .get<CreateOrderUseCase>();
                          final List<Map<String, int>> payload = CartService.instance.toOrderProductosPayload();
                          final Result<OrderEntity> result = await useCase(payload);

                          if (!context.mounted) return;

                          if (result.isSuccess) {
                            CartService.instance.clear();
                            final OrderEntity order = result.data!;
                            // persist last order and update cached list
                            final Map<String, dynamic> raw = order.raw ?? <String, dynamic>{
                              'id': order.id,
                              'total': order.total,
                              'estado': order.status,
                              'fecha_hora': order.placedAt,
                              'fecha_listo': order.readyAt ?? '',
                              'fecha_entregado': order.deliveredAt ?? '',
                              if (order.qr != null) 'qr': order.qr,
                            };
                            unawaited(LocalOrdersStorage.instance.saveLastOrder(raw));
                            LocalOrdersStorage.instance.readOrders().then((list) {
                              final List<Map<String, dynamic>> updated = <Map<String, dynamic>>[raw, ...list];
                              LocalOrdersStorage.instance.saveOrders(updated);
                            });
                            // Save order and items to relational DB
                            final items = data.map((e) => <String, dynamic>{
                              'productId': e.productId,
                              'name': e.name,
                              'quantity': e.quantity,
                              'unitPrice': e.unitPrice,
                            }).toList(growable: false);
                            unawaited(OrdersDb.instance.upsertOrder(
                              id: order.id,
                              orderNumber: order.id.toString(),
                              total: order.total,
                              status: order.status,
                              placedAt: order.placedAt,
                              readyAt: order.readyAt,
                              deliveredAt: order.deliveredAt,
                              items: items,
                            ));
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
                            // Network-aware fallback: enqueue for eventual connectivity
                            final String err = result.error ?? 'Network error';
                            final bool looksNetwork = err.contains('SocketException') || err.contains('Connection refused') || err.contains('timeout') || err.contains('Network');
                            if (looksNetwork) {
                              await OrdersSyncService.instance.enqueue(payload);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('No internet. Your order will be placed automatically when you are back online.')),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(err)),
                              );
                            }
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

// Top-level function to run in a background isolate
double _subtotalIsolate(List<Map<String, num>> items) {
  double sum = 0.0;
  for (final Map<String, num> m in items) {
    final double price = (m['price'] ?? 0).toDouble();
    final int qty = (m['qty'] ?? 0).toInt();
    sum += price * qty;
  }
  return sum;
}

Future<double> _subtotalWithCache(List<Map<String, num>> payload) async {
  try {
    // Create a simple key from productId-qty pairs
    final String key = 'orders:subtotal:' + payload
        .map((m) => '${m['price']}:${m['qty']}')
        .join('|');
    final CacheContext<String> cache = StrategyFactory.createCacheContext();
    final CacheResult<String> cached = await cache.retrieve(key);
    if (cached.success && cached.data != null) {
      final double parsed = double.tryParse(cached.data!) ?? double.nan;
      if (parsed.isFinite) return parsed;
    }
    // Fallback to compute and then cache
    final double value = await compute<List<Map<String, num>>, double>(
      _subtotalIsolate,
      payload,
    );
    // ignore: discarded_futures
    cache.store(key, value.toString(), expiration: const Duration(minutes: 5));
    return value;
  } catch (_) {
    return compute<List<Map<String, num>>, double>(
      _subtotalIsolate,
      payload,
    );
  }
}

class _EditableProductTile extends StatelessWidget {
  final CartItemData item;
  const _EditableProductTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final Widget image = item.imageUrl.startsWith('http')
        ? CachedNetworkImage(
            imageUrl: item.imageUrl,
            fit: BoxFit.cover,
            placeholder: (BuildContext context, String _) => Container(
              color: Colors.black12,
              child: const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            errorWidget: (BuildContext context, String _, dynamic __) =>
                Container(
              color: Colors.black12,
              child: const Icon(Icons.image_not_supported),
            ),
          )
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
