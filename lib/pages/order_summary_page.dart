import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_tapandtoast/pages/order_pickup_page.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../services/session_manager.dart';

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
  final double taxRate;

  const OrderSummaryPage({super.key, required this.items, this.taxRate = 0.10});

  String _money(double v) => NumberFormat.simpleCurrency().format(v);

  @override
  Widget build(BuildContext context) {
    final subtotal = items.fold<double>(0, (s, e) => s + e.lineTotal);
    final taxes = subtotal * taxRate;
    final total = subtotal + taxes;

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
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            const Text(
              'Products',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            ...items.map((item) => _ProductTile(item: item)),
            const SizedBox(height: 16),
            const Divider(height: 32),
            const Text(
              'Total',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            _RowKV(label: 'Subtotal', value: _money(subtotal)),
            _RowKV(label: 'Taxes', value: _money(taxes)),
            const SizedBox(height: 4),
            const Divider(),
            _RowKV(label: 'Total', value: _money(total), isBold: true),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () async {
                try {
                  final String? token = await SessionManager.getAccessToken();
                  final String type =
                      (await SessionManager.getTokenType()) ?? 'Bearer';
                  final Uri url = Uri.parse('${ApiConfig.baseUrl}/compras/');

                  final http.Response res = await http.post(
                    url,
                    headers: <String, String>{
                      'Content-Type': 'application/json',
                      'Accept': 'application/json',
                      if (token != null && token.isNotEmpty)
                        'Authorization': '$type $token',
                    },
                    body: jsonEncode(<String, dynamic>{
                      'productos': items
                          .map(
                            (CartItem e) => <String, int>{
                              'id_producto': e.productId,
                              'cantidad': e.quantity,
                            },
                          )
                          .toList(),
                    }),
                  );

                  if (res.statusCode >= 200 && res.statusCode < 300) {
                    final dynamic data = jsonDecode(res.body);
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute<OrderPickupPage>(
                        builder: (_) => OrderPickupPage(
                          order: data as Map<String, dynamic>,
                        ),
                      ),
                    );
                  } else {
                    String message = 'No se pudo crear la compra';
                    try {
                      final dynamic data = jsonDecode(res.body);
                      if (data is Map && data['detail'] != null) {
                        message = data['detail'].toString();
                      }
                    } catch (_) {}
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(message)));
                  }
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Error de red: $e')));
                }
              },
              child: const Text('Confirm Order'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  final CartItem item;
  const _ProductTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final image = item.image.startsWith('http')
        ? Image.network(item.image, fit: BoxFit.cover)
        : Image.asset(item.image, fit: BoxFit.cover);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(width: 56, height: 56, child: image),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Quantity: ${item.quantity}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ),
              ],
            ),
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
