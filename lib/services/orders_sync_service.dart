import 'dart:async';

import 'package:get_it/get_it.dart';

import '../core/result.dart';
import '../domain/entities/order.dart';
import '../domain/usecases/create_order_usecase.dart';
import 'connectivity_service.dart';
import 'local_orders_storage.dart';
import 'orders_db.dart';

/// Processes pending (outbox) orders when the device is online.
class OrdersSyncService {
  OrdersSyncService._();
  static final OrdersSyncService instance = OrdersSyncService._();

  StreamSubscription<bool>? _onlineSub;
  bool _running = false;

  Future<void> start() async {
    if (_running) return;
    _running = true;
    // Kick once on start if we're online
    if (ConnectivityService.instance.isOnline) {
      unawaited(_drainOutbox());
    }
    _onlineSub = ConnectivityService.instance.online$.listen((bool online) {
      if (online) {
        unawaited(_drainOutbox());
      }
    });
  }

  Future<void> stop() async {
    await _onlineSub?.cancel();
    _running = false;
  }

  /// Adds a pending order payload to the outbox.
  Future<void> enqueue(List<Map<String, int>> orderPayload) async {
    final List<Map<String, dynamic>> queue = await LocalOrdersStorage.instance.readPendingOrders();
    queue.add(<String, dynamic>{
      'payload': orderPayload,
      'ts': DateTime.now().toIso8601String(),
    });
    await LocalOrdersStorage.instance.savePendingOrders(queue);
  }

  Future<void> _drainOutbox() async {
    final List<Map<String, dynamic>> queue = await LocalOrdersStorage.instance.readPendingOrders();
    if (queue.isEmpty) return;

    final GetIt di = GetIt.I;
    final CreateOrderUseCase create = di.get<CreateOrderUseCase>();

    final List<Map<String, dynamic>> remaining = <Map<String, dynamic>>[];

    for (final Map<String, dynamic> entry in queue) {
      final List<Map<String, int>> payload = (entry['payload'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map((e) => Map<String, int>.from(e))
          .toList();
      try {
        final Result<OrderEntity> res = await create(payload);
        if (res.isSuccess) {
          final OrderEntity order = res.data!;
          // Update offline caches
          final Map<String, dynamic> raw = order.raw ?? <String, dynamic>{
            'id': order.id,
            'total': order.total,
            'estado': order.status,
            'fecha_hora': order.placedAt,
            'fecha_listo': order.readyAt ?? '',
            'fecha_entregado': order.deliveredAt ?? '',
            if (order.qr != null) 'qr': order.qr,
          };

          // Prepend to cached list
          final List<Map<String, dynamic>> existing = await LocalOrdersStorage.instance.readOrders();
          await LocalOrdersStorage.instance.saveOrders(<Map<String, dynamic>>[raw, ...existing]);

          // Save to relational DB as well
          final List<Map<String, dynamic>> items = payload
                  .map((e) => <String, dynamic>{
                        'productId': e['id_producto'] ?? 0,
                        'name': '',  // Name not available in payload
                        'quantity': e['cantidad'] ?? 0,
                        'unitPrice': (e['precio'] ?? 0).toDouble(),
                      })
                  .toList(growable: false);

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
        } else {
          // Keep in queue if server rejected due to non-network (conservative)
          remaining.add(entry);
        }
      } catch (_) {
        // Likely network issue during drain; keep entry
        remaining.add(entry);
      }
    }

    if (remaining.length != queue.length) {
      await LocalOrdersStorage.instance.savePendingOrders(remaining);
    }
  }
}


