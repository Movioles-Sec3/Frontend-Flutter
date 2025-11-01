import 'dart:async';

import 'package:flutter/material.dart';
import '../services/connectivity_service.dart';

class OfflineNotice extends StatefulWidget {
  const OfflineNotice({super.key});

  @override
  State<OfflineNotice> createState() => _OfflineNoticeState();
}

class _OfflineNoticeState extends State<OfflineNotice> {
  bool _online = true;
  StreamSubscription<bool>? _sub;

  @override
  void initState() {
    super.initState();
    // Initialize (idempotent)
    // ignore: discarded_futures
    ConnectivityService.instance.initialize();
    _online = ConnectivityService.instance.isOnline;
    _sub = ConnectivityService.instance.online$.listen((bool online) {
      if (!mounted) return;
      setState(() {
        _online = online;
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_online) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange),
      ),
      child: const Row(
        children: <Widget>[
          Icon(Icons.wifi_off, color: Colors.orange),
          SizedBox(width: 8),
          Expanded(child: Text('You are offline. Showing cached content.')),
        ],
      ),
    );
  }
}
