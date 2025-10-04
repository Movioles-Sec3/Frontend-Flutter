import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:intl/intl.dart';
import 'package:screen_brightness/screen_brightness.dart';

class OrderPickupPage extends StatefulWidget {
  final Map<String, dynamic> order;

  const OrderPickupPage({super.key, required this.order});

  @override
  State<OrderPickupPage> createState() => _OrderPickupPageState();
}

class _OrderPickupPageState extends State<OrderPickupPage>
    with WidgetsBindingObserver {
  final ScreenBrightness _screenBrightness = ScreenBrightness();
  double? _originalBrightness;
  bool _hasBoostedBrightness = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _boostBrightness();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_restoreBrightness());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _boostBrightness();
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _restoreBrightness();
    }
  }

  Future<void> _boostBrightness() async {
    if (_hasBoostedBrightness) return;
    try {
      final current = await _screenBrightness.current;
      if (!mounted) return;
      _originalBrightness ??= current;
      await _screenBrightness.setScreenBrightness(1.0);
      if (!mounted) return;
      _hasBoostedBrightness = true;
    } catch (_) {}
  }

  Future<void> _restoreBrightness() async {
    if (!_hasBoostedBrightness || _originalBrightness == null) return;
    try {
      await _screenBrightness.setScreenBrightness(
        _originalBrightness!.clamp(0.0, 1.0),
      );
    } catch (_) {
      // Ignore failures when attempting to restore
    } finally {
      _hasBoostedBrightness = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final String? qrHash = order['qr'] is Map
        ? (order['qr']['codigo_qr_hash']?.toString())
        : null;
    final String qrData = (qrHash != null && qrHash.isNotEmpty)
        ? qrHash
        : jsonEncode(order);
    final orderId = order['id']?.toString() ?? '—';
    final total = (order['total'] ?? 0.0) as num;
    final nf = NumberFormat.simpleCurrency();
    final String placedIso = (order['fecha_hora'] ?? '').toString();
    String placedAt;
    try {
      placedAt = DateFormat(
        'yyyy-MM-dd HH:mm',
      ).format(DateTime.parse(placedIso).toLocal());
    } catch (_) {
      placedAt = placedIso.isEmpty ? '—' : placedIso;
    }

    // Compute delivered wait (time between ready and delivered) if available
    Duration? deliveredWait;
    try {
      final String readyIso = (order['fecha_listo'] ?? '').toString();
      final String deliveredIso = (order['fecha_entregado'] ?? '').toString();
      if (readyIso.isNotEmpty && deliveredIso.isNotEmpty) {
        final DateTime ready = DateTime.parse(readyIso).toLocal();
        final DateTime delivered = DateTime.parse(deliveredIso).toLocal();
        if (delivered.isAfter(ready)) {
          deliveredWait = delivered.difference(ready);
        }
      }
    } catch (_) {}
    final brightness = MediaQuery.of(context).platformBrightness;
    final isDarkMode = brightness == Brightness.dark;
    final backgroundColor = isDarkMode ? Colors.black : const Color(0xFFFFF5F0);
    final infoTextColor = isDarkMode ? Colors.white70 : Colors.black87;
    final qrContainerColor = isDarkMode
        ? const Color(0xFF121212)
        : const Color(0xFFFFE0D5);
    final qrCardColor = isDarkMode ? Colors.black : Colors.white;
    final qrBorderColor = isDarkMode
        ? Colors.white.withOpacity(0.65)
        : Colors.black.withOpacity(0.2);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: isDarkMode ? Colors.white : Colors.black,
        elevation: 0,
        title: const Text('Order Pickup'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
          children: [
            const SizedBox(height: 4),
            Center(
              child: Text(
                'Show this code to the staff',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: infoTextColor,
                ),
              ),
            ),
            const SizedBox(height: 24),

            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: qrContainerColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: isDarkMode
                        ? Colors.black.withOpacity(0.4)
                        : Colors.orange.withOpacity(0.25),
                    blurRadius: 24,
                    spreadRadius: 1,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: qrCardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: qrBorderColor, width: 2),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: QrImageView(
                      data: qrData,
                      version: QrVersions.auto,
                      size: 240,
                      gapless: true,
                      eyeStyle: QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
                      dataModuleStyle: QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
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
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: infoTextColor,
                    ),
                  ),
                ),
                Text(
                  nf.format(total),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: infoTextColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Placed at: $placedAt',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: infoTextColor.withOpacity(0.85),
              ),
            ),
            if (deliveredWait != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                'Delivered wait: '
                '${deliveredWait.inMinutes.remainder(60).toString().padLeft(2, '0')}'
                'm '
                '${(deliveredWait.inSeconds.remainder(60)).toString().padLeft(2, '0')}'
                's',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: infoTextColor.withOpacity(0.85),
                ),
              ),
            ],
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
