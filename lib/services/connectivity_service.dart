import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Optimized connectivity wrapper that exposes online/offline status.
/// Uses event-driven approach to minimize CPU usage.
class ConnectivityService {
  ConnectivityService._();
  static final ConnectivityService instance = ConnectivityService._();

  final StreamController<bool> _onlineController = StreamController<bool>.broadcast();
  bool _isOnline = true;
  StreamSubscription<List<ConnectivityResult>>? _sub;
  DateTime? _lastCheck;
  static const Duration _minCheckInterval = Duration(milliseconds: 500);

  bool get isOnline => _isOnline;
  Stream<bool> get online$ => _onlineController.stream;

  Future<void> initialize() async {
    // Initial check with timeout protection
    try {
      final List<ConnectivityResult> initial = await Connectivity()
          .checkConnectivity()
          .timeout(const Duration(seconds: 2));
      _setOnline(_hasInternetLike(initial));
    } catch (_) {
      // Assume online if check fails
      _setOnline(true);
    }

    // Subscribe to connectivity changes (event-driven, not polling)
    _sub?.cancel();
    _sub = Connectivity().onConnectivityChanged.listen(
      (List<ConnectivityResult> list) {
        // Throttle rapid changes to reduce CPU spikes
        final now = DateTime.now();
        if (_lastCheck != null &&
            now.difference(_lastCheck!) < _minCheckInterval) {
          return;
        }
        _lastCheck = now;
        _setOnline(_hasInternetLike(list));
      },
      cancelOnError: false,
    );
  }

  void _setOnline(bool next) {
    if (_isOnline == next) return;
    _isOnline = next;
    if (_onlineController.hasListener) {
      _onlineController.add(_isOnline);
    }
  }

  bool _hasInternetLike(List<ConnectivityResult> results) {
    // Fast path: check if list is empty
    if (results.isEmpty) return false;

    // Use for loop instead of forEach for better performance
    for (int i = 0; i < results.length; i++) {
      final ConnectivityResult r = results[i];
      if (r == ConnectivityResult.mobile ||
          r == ConnectivityResult.wifi ||
          r == ConnectivityResult.ethernet ||
          r == ConnectivityResult.vpn) {
        return true;
      }
    }
    return false;
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
    await _onlineController.close();
  }
}


