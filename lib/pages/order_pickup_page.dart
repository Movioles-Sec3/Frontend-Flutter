import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:intl/intl.dart';

class OrderPickupPage extends StatelessWidget {
  /// Estructura libre; puede ser tu Order/Cart real.
  final Map<String, dynamic> order;

  const OrderPickupPage({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final qrData = jsonEncode(order);
    final orderId = order['id']?.toString() ?? '—';
    final total = (order['total'] ?? 0.0) as num;
    final nf = NumberFormat.simpleCurrency();

    return Scaffold(
      appBar: AppBar(title: const Text('Order Pickup'), centerTitle: true),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
          children: [
            const SizedBox(height: 4),
            const Center(
              child: Text(
                'Show this code to the staff',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 24),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFFFE0D5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Card(
                  elevation: 6,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: QrImageView(
                      data: qrData,
                      version: QrVersions.auto,
                      size: 240,
                      gapless: true,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Order #$orderId',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
                Text(
                  nf.format(total),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Placed at: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 24),

            FilledButton.icon(
              onPressed: () {
                Navigator.popUntil(
                  context,
                  (r) => r.isFirst,
                ); // vuelve al inicio
              },
              icon: const Icon(Icons.check),
              label: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }
}
