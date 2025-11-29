import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

/// Persists and exposes recent product search queries.
class SearchHistoryService extends ChangeNotifier {
  SearchHistoryService();

  static const String _boxName = 'search_history';
  static const String _key = 'recent_queries';
  static const int maxEntries = 4;

  Box<dynamic>? _box;
  List<String> _history = <String>[];

  /// Latest queries, most recent first.
  List<String> get history => List.unmodifiable(_history);

  Future<void> init() async {
    _box ??= await Hive.openBox<dynamic>(_boxName);
    final dynamic stored = _box!.get(_key);
    if (stored is List) {
      _history = stored.whereType<String>().toList(growable: false);
    }
  }

  Future<void> addQuery(String query) async {
    await init();
    final String trimmed = query.trim();
    if (trimmed.isEmpty) return;

    final String normalized = trimmed.toLowerCase();
    _history = _history
        .where((element) => element.toLowerCase() != normalized)
        .toList(growable: true);
    _history.insert(0, trimmed);
    if (_history.length > maxEntries) {
      _history = _history.sublist(0, maxEntries);
    }
    await _persist();
    notifyListeners();
  }

  Future<void> remove(String query) async {
    await init();
    final String normalized = query.trim().toLowerCase();
    final int before = _history.length;
    _history = _history
        .where((element) => element.toLowerCase() != normalized)
        .toList(growable: true);
    if (before != _history.length) {
      await _persist();
      notifyListeners();
    }
  }

  Future<void> clear() async {
    await init();
    if (_history.isEmpty) return;
    _history = <String>[];
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    await _box?.put(_key, _history);
  }
}
