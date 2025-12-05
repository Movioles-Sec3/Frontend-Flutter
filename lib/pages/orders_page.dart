import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:get_it/get_it.dart';
import '../core/result.dart';
import '../core/strategies/caching_strategy.dart';
import '../core/strategies/strategy_factory.dart';
import '../core/models/product_detail_data.dart';
import '../domain/entities/order.dart';
import '../domain/usecases/get_my_orders_usecase.dart';
import '../domain/usecases/get_order_details_usecase.dart';
import '../services/cart_service.dart';
import '../services/local_orders_storage.dart';
import '../services/orders_db.dart';
import '../services/orders_file_storage.dart';
import '../services/product_local_storage.dart';
import '../services/local_catalog_storage.dart';
import 'order_pickup_page.dart';
import 'orders_storage_manager_page.dart';
import '../services/connectivity_service.dart';
import '../services/orders_sync_service.dart';
import '../services/pending_reorders_service.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  bool _loading = true;
  String? _error;
  List<OrderEntity> _orders = <OrderEntity>[];
  bool _online = true;
  int _pending = 0;
  StreamSubscription<bool>? _onlineSub;
  StreamSubscription<int>? _reorderSuccessSub;

  @override
  void initState() {
    super.initState();
    // Initialize connectivity + sync services
    // ignore: discarded_futures
    ConnectivityService.instance.initialize();
    // ignore: discarded_futures
    OrdersSyncService.instance.start();
    // ignore: discarded_futures
    PendingReordersService.instance.initialize();
    _online = ConnectivityService.instance.isOnline;
    _onlineSub = ConnectivityService.instance.online$.listen((bool online) {
      setState(() {
        _online = online;
      });
      _refreshPendingCount();
      if (online) {
        // Kick a refresh to update list after potential sync
        _load();
      }
    });

    // Listen for successful pending reorder processing
    _reorderSuccessSub = PendingReordersService.instance.reorderSuccess$.listen((int count) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$count pending order${count > 1 ? 's' : ''} added to cart!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    });

    _refreshPendingCount();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    // Try cached list immediately (LRU/hybrid via StrategyFactory)
    try {
      final CacheContext<String> cache = StrategyFactory.createCacheContext();
      final CacheResult<String> cached = await cache.retrieve('orders:list');
      if (cached.success && mounted) {
        final List<dynamic> arr = (cached.data?.isNotEmpty ?? false)
            ? (jsonDecode(cached.data!) as List<dynamic>)
            : <dynamic>[];
        final List<OrderEntity> parsed = arr
            .cast<Map<String, dynamic>>()
            .map(
              (m) => OrderEntity(
                id: (m['id'] as num?)?.toInt() ?? 0,
                total: ((m['total'] ?? 0) as num).toDouble(),
                status: (m['estado'] ?? '').toString(),
                placedAt: (m['fecha_hora'] ?? '').toString(),
                readyAt: (m['fecha_listo'] ?? '').toString(),
                deliveredAt: (m['fecha_entregado'] ?? '').toString(),
                qr: (m['qr']),
                raw: m,
              ),
            )
            .toList(growable: false);
        if (parsed.isNotEmpty) {
          setState(() {
            _orders = parsed;
            _loading = false;
          });
        }
      }
    } catch (_) {}

    final GetMyOrdersUseCase useCase = GetIt.I.get<GetMyOrdersUseCase>();
    // Future with then/catchError handlers
    return useCase()
        .then((Result<List<OrderEntity>> result) {
          if (!mounted) return;
          if (result.isSuccess) {
            setState(() {
              _orders = result.data!;
              _loading = false;
            });
            // Save to cache (orders:list) using LRU strategy (orders: prefix)
            try {
              final List<Map<String, dynamic>> raw = _orders
                  .map(
                    (o) =>
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
                  )
                  .toList(growable: false);
              final CacheContext<String> cache =
                  StrategyFactory.createCacheContext();
              // ignore: discarded_futures
              cache.store(
                'orders:list',
                jsonEncode(raw),
                expiration: const Duration(minutes: 10),
              );
            } catch (_) {}
            // Save to relational DB
            unawaited(_persistOrdersToDb(_orders));
            // persist orders locally for offline access
            final List<Map<String, dynamic>> raw = _orders
                .map(
                  (o) =>
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
                )
                .toList(growable: false);
            LocalOrdersStorage.instance.saveOrders(raw);
            // Also save to file storage for persistent backup
            unawaited(OrdersFileStorage.instance.saveOrdersList(raw));
          } else {
            // Try offline fallback from DB first, then shared cache
            OrdersDb.instance.getOrders().then((rows) async {
              if (!mounted) return;
              if (rows.isNotEmpty) {
                setState(() {
                  _orders = rows
                      .map(
                        (m) => OrderEntity(
                          id: (m['id'] as num?)?.toInt() ?? 0,
                          total: ((m['total'] ?? 0) as num).toDouble(),
                          status: (m['status'] ?? '').toString(),
                          placedAt: (m['placed_at'] ?? '').toString(),
                          readyAt: (m['ready_at'] ?? '').toString(),
                          deliveredAt: (m['delivered_at'] ?? '').toString(),
                          qr: null,
                          raw: <String, dynamic>{
                            'id': m['id'],
                            'total': m['total'],
                            'estado': m['status'],
                            'fecha_hora': m['placed_at'],
                            'fecha_listo': m['ready_at'],
                            'fecha_entregado': m['delivered_at'],
                          },
                        ),
                      )
                      .toList();
                  _loading = false;
                  _error = null;
                });
                return;
              }
              // fallback to cached list
              final list = await LocalOrdersStorage.instance.readOrders();
              if (!mounted) return;
              if (list.isNotEmpty) {
                setState(() {
                  _orders = list
                      .map(
                        (m) => OrderEntity(
                          id: (m['id'] as num?)?.toInt() ?? 0,
                          total: ((m['total'] ?? 0) as num).toDouble(),
                          status: (m['estado'] ?? '').toString(),
                          placedAt: (m['fecha_hora'] ?? '').toString(),
                          readyAt: (m['fecha_listo'] ?? '').toString(),
                          deliveredAt: (m['fecha_entregado'] ?? '').toString(),
                          qr: (m['qr']),
                          raw: m,
                        ),
                      )
                      .toList();
                  _loading = false;
                  _error = null;
                });
              } else {
                // Final fallback: try file storage
                final fileList = await OrdersFileStorage.instance.readOrdersList();
                if (!mounted) return;
                if (fileList.isNotEmpty) {
                  setState(() {
                    _orders = fileList
                        .map(
                          (m) => OrderEntity(
                            id: (m['id'] as num?)?.toInt() ?? 0,
                            total: ((m['total'] ?? 0) as num).toDouble(),
                            status: (m['estado'] ?? '').toString(),
                            placedAt: (m['fecha_hora'] ?? '').toString(),
                            readyAt: (m['fecha_listo'] ?? '').toString(),
                            deliveredAt: (m['fecha_entregado'] ?? '').toString(),
                            qr: (m['qr']),
                            raw: m,
                          ),
                        )
                        .toList();
                    _loading = false;
                    _error = null;
                  });
                } else {
                  setState(() {
                    _error = _formatError(result.error);
                    _loading = false;
                  });
                }
              }
            });
          }
        })
        .catchError((Object e) {
          if (!mounted) return;
          // Try offline fallback: DB first, then shared cache
          OrdersDb.instance.getOrders().then((rows) async {
            if (!mounted) return;
            if (rows.isNotEmpty) {
              setState(() {
                _orders = rows
                    .map(
                      (m) => OrderEntity(
                        id: (m['id'] as num?)?.toInt() ?? 0,
                        total: ((m['total'] ?? 0) as num).toDouble(),
                        status: (m['status'] ?? '').toString(),
                        placedAt: (m['placed_at'] ?? '').toString(),
                        readyAt: (m['ready_at'] ?? '').toString(),
                        deliveredAt: (m['delivered_at'] ?? '').toString(),
                        qr: null,
                        raw: <String, dynamic>{
                          'id': m['id'],
                          'total': m['total'],
                          'estado': m['status'],
                          'fecha_hora': m['placed_at'],
                          'fecha_listo': m['ready_at'],
                          'fecha_entregado': m['delivered_at'],
                        },
                      ),
                    )
                    .toList();
                _loading = false;
                _error = null;
              });
            } else {
              final list = await LocalOrdersStorage.instance.readOrders();
              if (list.isNotEmpty) {
                setState(() {
                  _orders = list
                      .map(
                        (m) => OrderEntity(
                          id: (m['id'] as num?)?.toInt() ?? 0,
                          total: ((m['total'] ?? 0) as num).toDouble(),
                          status: (m['estado'] ?? '').toString(),
                          placedAt: (m['fecha_hora'] ?? '').toString(),
                          readyAt: (m['fecha_listo'] ?? '').toString(),
                          deliveredAt: (m['fecha_entregado'] ?? '').toString(),
                          qr: (m['qr']),
                          raw: m,
                        ),
                      )
                      .toList();
                  _loading = false;
                  _error = null;
                });
              } else {
                // Final fallback: try file storage
                final fileList = await OrdersFileStorage.instance.readOrdersList();
                if (!mounted) return;
                if (fileList.isNotEmpty) {
                  setState(() {
                    _orders = fileList
                        .map(
                          (m) => OrderEntity(
                            id: (m['id'] as num?)?.toInt() ?? 0,
                            total: ((m['total'] ?? 0) as num).toDouble(),
                            status: (m['estado'] ?? '').toString(),
                            placedAt: (m['fecha_hora'] ?? '').toString(),
                            readyAt: (m['fecha_listo'] ?? '').toString(),
                            deliveredAt: (m['fecha_entregado'] ?? '').toString(),
                            qr: (m['qr']),
                            raw: m,
                          ),
                        )
                        .toList();
                    _loading = false;
                    _error = null;
                  });
                } else {
                  setState(() {
                    _error = _formatError(e.toString());
                    _loading = false;
                  });
                }
              }
            }
          });
        });
  }

  Future<void> _refreshPendingCount() async {
    final List<Map<String, dynamic>> q = await LocalOrdersStorage.instance
        .readPendingOrders();
    if (!mounted) return;
    setState(() {
      _pending = q.length;
    });
  }

  Future<void> _persistOrdersToDb(List<OrderEntity> orders) async {
    // Save last 20 orders with their items
    final int ordersToSave = orders.length > 20 ? 20 : orders.length;
    final GetOrderDetailsUseCase orderDetailsUseCase = GetIt.I.get<GetOrderDetailsUseCase>();

    // Initialize product cache for saving product images
    final ProductLocalStorage productCache = ProductLocalStorage();
    await productCache.init();

    for (int i = 0; i < ordersToSave; i++) {
      final OrderEntity o = orders[i];

      try {
        // Fetch order items from API
        final Result<List<Map<String, dynamic>>> itemsResult = await orderDetailsUseCase(o.id);

        List<Map<String, dynamic>> items = [];
        if (itemsResult.isSuccess && itemsResult.data != null) {
          // Convert API format to DB format and save products to cache
          for (final apiItem in itemsResult.data!) {
            final int productId = (apiItem['id_producto'] as num?)?.toInt() ?? 0;
            final String imageUrl = (apiItem['imagen_url'] ?? '').toString();

            items.add(<String, dynamic>{
              'productId': productId,
              'name': (apiItem['nombre'] ?? '').toString(),
              'quantity': (apiItem['cantidad'] as num?)?.toInt() ?? 0,
              'unitPrice': ((apiItem['precio'] ?? 0) as num).toDouble(),
            });

            // Save product to cache if we have image URL (for future reorders)
            if (imageUrl.isNotEmpty) {
              try {
                await productCache.saveProduct(
                  PreparedProductData(
                    id: productId,
                    typeId: 0, // Not available from order details
                    name: (apiItem['nombre'] ?? '').toString(),
                    description: '', // Not available from order details
                    imageUrl: imageUrl,
                    price: ((apiItem['precio'] ?? 0) as num).toDouble(),
                    available: true,
                    heroTag: 'product-$productId',
                    note: '',
                    timesOrdered: 0,
                  ),
                );
                debugPrint('✅ Cached product $productId with image: $imageUrl');
              } catch (e) {
                debugPrint('❌ Failed to cache product $productId: $e');
              }
            } else {
              debugPrint('⚠️ No image URL for product $productId');
            }
          }
        }

        // Save order with items to database
        await OrdersDb.instance.upsertOrder(
          id: o.id,
          orderNumber: o.id.toString(),
          total: o.total,
          status: o.status,
          placedAt: o.placedAt,
          readyAt: o.readyAt,
          deliveredAt: o.deliveredAt,
          items: items,
        );
      } catch (e) {
        // If fetching items fails, save order without items
        // This ensures order metadata is still saved
        await OrdersDb.instance.upsertOrder(
          id: o.id,
          orderNumber: o.id.toString(),
          total: o.total,
          status: o.status,
          placedAt: o.placedAt,
          readyAt: o.readyAt,
          deliveredAt: o.deliveredAt,
          items: const <Map<String, dynamic>>[],
        );
      }
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

  String _formatError(String? raw) {
    final String normalized = (raw ?? '').toLowerCase();
    if (normalized.contains('socket') ||
        normalized.contains('network') ||
        normalized.contains('failed host lookup') ||
        normalized.contains('connection refused') ||
        normalized.contains('timeout') ||
        normalized.contains('internet')) {
      return 'We could not update your orders because you are offline. Please check your internet connection and try again.';
    }
    if ((raw ?? '').trim().isEmpty) {
      return 'We could not load your orders. Please try again in a few seconds.';
    }
    return raw!;
  }

  Future<void> _reorder(int orderId) async {
    try {
      // Fetch order items from local database
      final List<Map<String, dynamic>> orderItems = await OrdersDb.instance.getOrderItems(orderId);

      if (orderItems.isEmpty) {
        // Try to fetch from API and save for future use
        if (_online) {
          try {
            final GetOrderDetailsUseCase useCase = GetIt.I.get<GetOrderDetailsUseCase>();
            final Result<List<Map<String, dynamic>>> result = await useCase(orderId);

            if (result.isSuccess && result.data != null && result.data!.isNotEmpty) {
              // Initialize product cache
              final ProductLocalStorage productCache = ProductLocalStorage();
              await productCache.init();

              // Save to database for future reorders
              final List<Map<String, dynamic>> items = [];
              for (final apiItem in result.data!) {
                final int productId = (apiItem['id_producto'] as num?)?.toInt() ?? 0;
                final String imageUrl = (apiItem['imagen_url'] ?? '').toString();

                items.add(<String, dynamic>{
                  'productId': productId,
                  'name': (apiItem['nombre'] ?? '').toString(),
                  'quantity': (apiItem['cantidad'] as num?)?.toInt() ?? 0,
                  'unitPrice': ((apiItem['precio'] ?? 0) as num).toDouble(),
                });

                // Save product to cache with image URL
                if (imageUrl.isNotEmpty) {
                  try {
                    await productCache.saveProduct(
                      PreparedProductData(
                        id: productId,
                        typeId: 0,
                        name: (apiItem['nombre'] ?? '').toString(),
                        description: '',
                        imageUrl: imageUrl,
                        price: ((apiItem['precio'] ?? 0) as num).toDouble(),
                        available: true,
                        heroTag: 'product-$productId',
                        note: '',
                        timesOrdered: 0,
                      ),
                    );
                  } catch (e) {
                    debugPrint('Failed to cache product $productId: $e');
                  }
                }
              }

              // Find the order to get its details
              final OrderEntity? order = _orders.cast<OrderEntity?>().firstWhere(
                (o) => o?.id == orderId,
                orElse: () => null,
              );

              await OrdersDb.instance.upsertOrder(
                id: orderId,
                orderNumber: orderId.toString(),
                total: order?.total ?? 0,
                status: order?.status ?? 'UNKNOWN',
                placedAt: order?.placedAt ?? DateTime.now().toIso8601String(),
                readyAt: order?.readyAt,
                deliveredAt: order?.deliveredAt,
                items: items,
              );

              // Now add to cart
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
              return;
            }
          } catch (_) {
            // Fall through to error message
          }
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_online
                ? 'Unable to load order items. This order may no longer be available.'
                : 'This order is not saved locally. Please connect to the internet and refresh your orders, then try again.'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 5),
            ),
          );
        }
        return;
      }

      // Convert database format to cart format and fetch image URLs from catalog cache
      final ProductLocalStorage productCache = ProductLocalStorage();
      await productCache.init();

      // Fetch all products first to build an image URL map
      final Map<int, String> imageUrlMap = <int, String>{};
      for (final item in orderItems) {
        final int productId = (item['product_id'] as num?)?.toInt() ?? 0;
        if (productId > 0 && !imageUrlMap.containsKey(productId)) {
          try {
            // First try: LocalCatalogStorage (main catalog/home page products)
            final catalogProduct = await LocalCatalogStorage.instance.readProduct(productId);
            if (catalogProduct != null) {
              final String imageUrl = (catalogProduct['imagen_url'] ?? catalogProduct['imageUrl'] ?? '').toString();
              if (imageUrl.isNotEmpty) {
                imageUrlMap[productId] = imageUrl;
                debugPrint('✅ Found image for product $productId from catalog: $imageUrl');
                continue;
              }
            }

            // Second try: ProductLocalStorage (browsed products cache)
            final product = await productCache.getProduct(productId);
            if (product != null && product.imageUrl.isNotEmpty) {
              imageUrlMap[productId] = product.imageUrl;
              debugPrint('✅ Found image for product $productId from product cache: ${product.imageUrl}');
            } else {
              debugPrint('⚠️ No image found for product $productId in any cache');
            }
          } catch (e) {
            debugPrint('❌ Failed to fetch product $productId from cache: $e');
          }
        }
      }

      debugPrint('📦 Total products: ${orderItems.length}, Images found: ${imageUrlMap.length}');

      // Build products list with image URLs
      final List<Map<String, dynamic>> products = orderItems.map((item) {
        final int productId = (item['product_id'] as num?)?.toInt() ?? 0;
        final String imageUrl = imageUrlMap[productId] ?? '';

        return <String, dynamic>{
          'id_producto': productId,
          'nombre': item['name'],
          'cantidad': item['quantity'],
          'precio': item['unit_price'],
          'imagen_url': imageUrl,
        };
      }).toList();

      // Add items to cart
      final CartService cartService = CartService.instance;
      cartService.reorderFromOrder(products);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order items added to cart!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error reordering: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
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

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: () async {
            await _refreshPendingCount();
            return _load();
          },
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _orders.length + _headerCount,
        itemBuilder: (BuildContext context, int index) {
          if (index < _headerCount) {
            return _buildHeader(index);
          }
          final int dataIndex = index - _headerCount;
          final OrderEntity o = _orders[dataIndex];
          final int id = o.id;
          final double total = o.total;
          final String estado = o.status;
          final String fecha = o.placedAt;
          final Color statusColor = _statusColor(estado, context);

          return RepaintBoundary(
            child: Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: statusColor.withValues(alpha: 0.15),
                  child: Text(
                    id.toString(),
                    style: TextStyle(
                      color: statusColor,
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
                      itemBuilder: (BuildContext context) =>
                          <PopupMenuEntry<String>>[
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
                      icon: const Icon(Icons.more_vert),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
        ),
        // Floating Action Button for Storage Manager
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const OrdersStorageManagerPage(),
                ),
              );
            },
            tooltip: 'Manage Storage & Backups',
            child: const Icon(Icons.storage),
          ),
        ),
      ],
    );
  }

  int get _headerCount => (_online ? 0 : 1) + (_pending > 0 ? 1 : 0);

  Widget _buildHeader(int index) {
    final bool showOffline = !_online;
    if (showOffline && index == 0) {
      return Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange),
        ),
        child: const Row(
          children: <Widget>[
            Icon(Icons.wifi_off, color: Colors.orange),
            SizedBox(width: 8),
            Expanded(child: Text('You are offline. Showing cached orders.')),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blueAccent),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.cloud_upload, color: Colors.blueAccent),
          const SizedBox(width: 8),
          Expanded(
            child: Text('$_pending order(s) will be placed when back online.'),
          ),
        ],
      ),
    );
  }

  @override
  @override
  void dispose() {
    _onlineSub?.cancel();
    _reorderSuccessSub?.cancel();
    super.dispose();
  }
}
