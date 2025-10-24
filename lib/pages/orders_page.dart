import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:get_it/get_it.dart';
import '../core/result.dart';
import '../domain/entities/order.dart';
import '../domain/usecases/get_my_orders_usecase.dart';
import '../domain/usecases/get_order_details_usecase.dart';
import '../services/cart_service.dart';
import 'order_pickup_page.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  bool _loading = true;
  String? _error;
  List<OrderEntity> _orders = <OrderEntity>[];

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

    final GetMyOrdersUseCase useCase = GetIt.I.get<GetMyOrdersUseCase>();
    final Result<List<OrderEntity>> result = await useCase();

    if (!mounted) return;

    if (result.isSuccess) {
      setState(() {
        _orders = result.data!;
        _loading = false;
      });
    } else {
      setState(() {
        _error = result.error;
        _loading = false;
      });
    }
  }

  String _formatDate(String iso) {
    try {
      final DateTime dt = DateTime.parse(iso).toLocal();
      return DateFormat('yyyy-MM-dd HH:mm').format(dt);
    } catch (_) {
      return iso;
    }
  }

  Color _statusColor(String status, BuildContext context) {
    switch (status) {
      case 'PAGADO':
        return Colors.blue;
      case 'EN_PREPARACION':
        return Colors.orange;
      case 'LISTO':
        return Colors.green;
      case 'ENTREGADO':
        return Colors.grey;
      case 'CARRITO':
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }

  Future<void> _reorder(int orderId) async {
    try {
      final GetOrderDetailsUseCase useCase = GetIt.I.get<GetOrderDetailsUseCase>();
      final Result<List<Map<String, dynamic>>> result = await useCase(orderId);

      if (result.isSuccess && result.data != null) {
        final CartService cartService = CartService.instance;
        cartService.reorderFromOrder(result.data!);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Order items added to cart!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to reorder: ${result.error}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error reordering: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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

    if (_orders.isEmpty) {
      return const Center(child: Text('No orders yet.'));
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: _orders.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (BuildContext context, int index) {
          final OrderEntity o = _orders[index];
          final int id = o.id;
          final double total = o.total;
          final String estado = o.status;
          final String fecha = o.placedAt;

          return Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: _statusColor(
                  estado,
                  context,
                ).withOpacity(0.15),
                child: Text(
                  id.toString(),
                  style: TextStyle(
                    color: _statusColor(estado, context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              title: Text('Order #$id'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Status: $estado'),
                  Text('Placed at: ${_formatDate(fecha)}'),
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text('\$${total.toStringAsFixed(2)}'),
                  const SizedBox(width: 8),
                  PopupMenuButton<String>(
                    onSelected: (String value) {
                      if (value == 'reorder') {
                        _reorder(id);
                      } else if (value == 'view') {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => OrderPickupPage(
                              order:
                                  o.raw ??
                                  <String, dynamic>{
                                    'id': o.id,
                                    'total': o.total,
                                    'estado': o.status,
                                    'fecha_hora': o.placedAt,
                                    'fecha_listo': o.readyAt ?? '',
                                    'fecha_entregado': o.deliveredAt ?? '',
                                    if (o.qr != null) 'qr': o.qr,
                                  },
                            ),
                          ),
                        );
                      }
                    },
                    itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                      const PopupMenuItem<String>(
                        value: 'view',
                        child: Row(
                          children: <Widget>[
                            Icon(Icons.visibility),
                            SizedBox(width: 8),
                            Text('View Details'),
                          ],
                        ),
                      ),
                      const PopupMenuItem<String>(
                        value: 'reorder',
                        child: Row(
                          children: <Widget>[
                            Icon(Icons.shopping_cart),
                            SizedBox(width: 8),
                            Text('Reorder'),
                          ],
                        ),
                      ),
                    ],
                    child: const Icon(Icons.more_vert),
                  ),
                ],
              ),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => OrderPickupPage(
                      order:
                          o.raw ??
                          <String, dynamic>{
                            'id': o.id,
                            'total': o.total,
                            'estado': o.status,
                            'fecha_hora': o.placedAt,
                            'fecha_listo': o.readyAt ?? '',
                            'fecha_entregado': o.deliveredAt ?? '',
                            if (o.qr != null) 'qr': o.qr,
                          },
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
