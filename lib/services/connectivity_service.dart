import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Simple connectivity wrapper that exposes online/offline status.
class ConnectivityService {
  ConnectivityService._();
  static final ConnectivityService instance = ConnectivityService._();

  final StreamController<bool> _onlineController = StreamController<bool>.broadcast();
  bool _isOnline = true;
  StreamSubscription<List<ConnectivityResult>>? _sub;

  bool get isOnline => _isOnline;
  Stream<bool> get online$ => _onlineController.stream;

  Future<void> initialize() async {
    // Initial check
    final List<ConnectivityResult> initial = await Connectivity().checkConnectivity();
    _setOnline(_hasInternetLike(initial));

    _sub?.cancel();
    _sub = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> list) {
      _setOnline(_hasInternetLike(list));
    });
  }

  void _setOnline(bool next) {
    if (_isOnline == next) return;
    _isOnline = next;
    _onlineController.add(_isOnline);
  }

  bool _hasInternetLike(List<ConnectivityResult> results) {
    for (final ConnectivityResult r in results) {
      if (r == ConnectivityResult.mobile || r == ConnectivityResult.wifi || r == ConnectivityResult.ethernet || r == ConnectivityResult.vpn) {
        return true;
      }
    }
    return false;
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    await _onlineController.close();
  }
}


