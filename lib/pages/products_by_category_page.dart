import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../services/session_manager.dart';
import '../services/cart_service.dart';

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
  List<Map<String, dynamic>> _products = <Map<String, dynamic>>[];

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

    try {
      // If endpoint requires auth, attach token; if public, it will be ignored by backend
      final String? token = await SessionManager.getAccessToken();
      final String tokenType =
          (await SessionManager.getTokenType()) ?? 'Bearer';

      final Uri url = Uri.parse('${ApiConfig.baseUrl}/productos/');
      final http.Response res = await http.get(
        url,
        headers: <String, String>{
          if (token != null && token.isNotEmpty)
            'Authorization': '$tokenType $token',
          'Accept': 'application/json',
        },
      );

      if (!mounted) return;

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final dynamic data = jsonDecode(res.body);
        if (data is List) {
          final List<Map<String, dynamic>> all = data
              .whereType<Map<String, dynamic>>()
              .map((Map<String, dynamic> e) => e)
              .toList();
          final List<Map<String, dynamic>> filtered = all
              .where(
                (Map<String, dynamic> p) =>
                    (p['id_tipo'] as num?)?.toInt() == widget.categoryId,
              )
              .toList();
          setState(() {
            _products = filtered;
            _loading = false;
          });
        } else {
          setState(() {
            _error = 'Invalid server response';
            _loading = false;
          });
        }
      } else {
        String message = 'Could not fetch products';
        try {
          final dynamic data = jsonDecode(res.body);
          if (data is Map && data['detail'] != null) {
            message = data['detail'].toString();
          }
        } catch (_) {}
        setState(() {
          _error = message;
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Network error: $e';
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
        final Map<String, dynamic> p = _products[index];
        final String nombre = (p['nombre'] ?? '').toString();
        final String descripcion = (p['descripcion'] ?? '').toString();
        final String imagenUrl = (p['imagen_url'] ?? '').toString();
        final num precio = (p['precio'] ?? 0) as num;
        final bool disponible = (p['disponible'] ?? true) as bool;

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
                                      productId: (p['id'] as num).toInt(),
                                      name: nombre,
                                      imageUrl: imagenUrl,
                                      unitPrice: (precio).toDouble(),
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
