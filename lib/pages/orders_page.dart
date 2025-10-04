import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../services/session_manager.dart';
import 'login_page.dart';
import 'order_pickup_page.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _orders = <Map<String, dynamic>>[];

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

    final String? token = await SessionManager.getAccessToken();
    final String tokenType = (await SessionManager.getTokenType()) ?? 'Bearer';
    if (token == null || token.isEmpty) {
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const LoginPage()),
        (Route<dynamic> _) => false,
      );
      return;
    }

    try {
      final Uri url = Uri.parse('${ApiConfig.baseUrl}/compras/me');
      final http.Response res = await http.get(
        url,
        headers: <String, String>{
          'Authorization': '$tokenType $token',
          'Accept': 'application/json',
        },
      );

      if (!mounted) return;

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final dynamic data = jsonDecode(res.body);
        if (data is List) {
          setState(() {
            _orders = data.whereType<Map<String, dynamic>>().toList();
            _loading = false;
          });
        } else {
          setState(() {
            _error = 'Invalid server response';
            _loading = false;
          });
        }
      } else {
        String message = 'Could not fetch orders';
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
          final Map<String, dynamic> o = _orders[index];
          final int id = (o['id'] as num?)?.toInt() ?? 0;
          final num total = (o['total'] ?? 0) as num;
          final String estado = (o['estado'] ?? '').toString();
          final String fecha = (o['fecha_hora'] ?? '').toString();

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
              trailing: Text('\$${total.toStringAsFixed(2)}'),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => OrderPickupPage(order: o),
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
