import 'dart:convert';
import 'dart:collection';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'strategy.dart';

/// Cache data model
class CacheData<T> {
  CacheData({
    required this.key,
    required this.data,
    required this.timestamp,
    this.expirationTime,
  });

  final String key;
  final T data;
  final DateTime timestamp;
  final DateTime? expirationTime;

  bool get isExpired {
    if (expirationTime == null) return false;
    return DateTime.now().isAfter(expirationTime!);
  }

  Map<String, dynamic> toJson() => {
    'key': key,
    'data': data,
    'timestamp': timestamp.millisecondsSinceEpoch,
    'expirationTime': expirationTime?.millisecondsSinceEpoch,
  };

  factory CacheData.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic) fromJsonT,
  ) {
    return CacheData<T>(
      key: json['key'] as String,
      data: fromJsonT(json['data']),
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int),
      expirationTime: json['expirationTime'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['expirationTime'] as int)
          : null,
    );
  }
}

/// Cache result model
class CacheResult<T> {
  CacheResult({required this.success, this.data, this.error});

  final bool success;
  final T? data;
  final String? error;

  factory CacheResult.success(T data) => CacheResult(success: true, data: data);
  factory CacheResult.failure(String error) =>
      CacheResult(success: false, error: error);
}

/// Base caching strategy interface
abstract class CachingStrategy<T> extends Strategy<String, CacheResult<T>> {
  @override
  String get identifier;

  @override
  bool canHandle(String input) => true; // Most caching strategies can handle any key

  /// Store data in cache
  Future<CacheResult<bool>> store(String key, T data, {Duration? expiration});

  /// Retrieve data from cache
  Future<CacheResult<T>> retrieve(String key);

  /// Remove data from cache
  Future<CacheResult<bool>> remove(String key);

  /// Clear all cached data
  Future<CacheResult<bool>> clear();

  /// Check if key exists in cache
  Future<CacheResult<bool>> exists(String key);
}

/// LRU in-memory caching strategy
class LruMemoryCachingStrategy<T> extends CachingStrategy<T> {
  LruMemoryCachingStrategy({
    this.maxEntries = 128,
    this.keyPrefixes = const <String>[],
  });

  @override
  String get identifier => 'lru_memory';

  /// Maximum number of entries to keep in cache
  final int maxEntries;

  /// If provided, this strategy will only handle keys that start with one of these prefixes
  final List<String> keyPrefixes;

  // LinkedHashMap preserves insertion order; we will simulate access-order by
  // removing and reinserting keys on access to move them to the end (MRU tail).
  final LinkedHashMap<String, CacheData<T>> _lruMap =
      LinkedHashMap<String, CacheData<T>>();

  @override
  bool canHandle(String key) {
    if (keyPrefixes.isEmpty) return true;
    for (final String p in keyPrefixes) {
      if (key.startsWith(p)) return true;
    }
    return false;
  }

  @override
  Future<CacheResult<T>> execute(String key) async {
    return retrieve(key);
  }

  @override
  Future<CacheResult<bool>> store(
    String key,
    T data, {
    Duration? expiration,
  }) async {
    try {
      final DateTime? expTime = expiration == null
          ? null
          : DateTime.now().add(expiration);
      final CacheData<T> payload = CacheData<T>(
        key: key,
        data: data,
        timestamp: DateTime.now(),
        expirationTime: expTime,
      );

      // If key exists, delete first to reinsert (becomes MRU)
      _lruMap.remove(key);
      _lruMap[key] = payload;

      // Evict LRU if over capacity
      while (_lruMap.length > maxEntries) {
        final String lruKey = _lruMap.keys.first;
        _lruMap.remove(lruKey);
      }

      return CacheResult.success(true);
    } catch (e) {
      return CacheResult.failure('Failed to store in LRU memory cache: $e');
    }
  }

  @override
  Future<CacheResult<T>> retrieve(String key) async {
    try {
      final CacheData<T>? found = _lruMap.remove(key);
      if (found == null)
        return CacheResult.failure('Key not found in LRU memory cache');

      // If expired, do not reinsert
      if (found.isExpired) {
        return CacheResult.failure('Cache entry expired');
      }

      // Reinsert to mark as MRU
      _lruMap[key] = found;
      return CacheResult.success(found.data);
    } catch (e) {
      return CacheResult.failure(
        'Failed to retrieve from LRU memory cache: $e',
      );
    }
  }

  @override
  Future<CacheResult<bool>> remove(String key) async {
    try {
      final bool removed = _lruMap.remove(key) != null;
      return CacheResult.success(removed);
    } catch (e) {
      return CacheResult.failure('Failed to remove from LRU memory cache: $e');
    }
  }

  @override
  Future<CacheResult<bool>> clear() async {
    try {
      _lruMap.clear();
      return CacheResult.success(true);
    } catch (e) {
      return CacheResult.failure('Failed to clear LRU memory cache: $e');
    }
  }

  @override
  Future<CacheResult<bool>> exists(String key) async {
    try {
      final CacheData<T>? found = _lruMap[key];
      if (found == null) return CacheResult.success(false);
      if (found.isExpired) {
        _lruMap.remove(key);
        return CacheResult.success(false);
      }
      return CacheResult.success(true);
    } catch (e) {
      return CacheResult.failure(
        'Failed to check existence in LRU memory cache: $e',
      );
    }
  }
}

/// In-memory caching strategy
class MemoryCachingStrategy<T> extends CachingStrategy<T> {
  MemoryCachingStrategy({this.maxSize = 100});

  @override
  String get identifier => 'memory';

  final int maxSize;
  final Map<String, CacheData<T>> _cache = {};

  @override
  Future<CacheResult<T>> execute(String key) async {
    return await retrieve(key);
  }

  @override
  Future<CacheResult<bool>> store(
    String key,
    T data, {
    Duration? expiration,
  }) async {
    try {
      // Remove oldest entries if cache is full
      if (_cache.length >= maxSize) {
        final oldestKey = _cache.keys.first;
        _cache.remove(oldestKey);
      }

      final expirationTime = expiration != null
          ? DateTime.now().add(expiration)
          : null;

      _cache[key] = CacheData<T>(
        key: key,
        data: data,
        timestamp: DateTime.now(),
        expirationTime: expirationTime,
      );

      return CacheResult.success(true);
    } catch (e) {
      return CacheResult.failure('Failed to store in memory cache: $e');
    }
  }

  @override
  Future<CacheResult<T>> retrieve(String key) async {
    try {
      final cacheData = _cache[key];
      if (cacheData == null) {
        return CacheResult.failure('Key not found in memory cache');
      }

      if (cacheData.isExpired) {
        _cache.remove(key);
        return CacheResult.failure('Cache entry expired');
      }

      return CacheResult.success(cacheData.data);
    } catch (e) {
      return CacheResult.failure('Failed to retrieve from memory cache: $e');
    }
  }

  @override
  Future<CacheResult<bool>> remove(String key) async {
    try {
      final removed = _cache.remove(key) != null;
      return CacheResult.success(removed);
    } catch (e) {
      return CacheResult.failure('Failed to remove from memory cache: $e');
    }
  }

  @override
  Future<CacheResult<bool>> clear() async {
    try {
      _cache.clear();
      return CacheResult.success(true);
    } catch (e) {
      return CacheResult.failure('Failed to clear memory cache: $e');
    }
  }

  @override
  Future<CacheResult<bool>> exists(String key) async {
    try {
      final exists = _cache.containsKey(key) && !_cache[key]!.isExpired;
      return CacheResult.success(exists);
    } catch (e) {
      return CacheResult.failure(
        'Failed to check existence in memory cache: $e',
      );
    }
  }
}

/// File-based caching strategy
class FileCachingStrategy<T> extends CachingStrategy<T> {
  FileCachingStrategy({
    required this.cacheDirectory,
    required this.serializer,
    required this.deserializer,
  });

  @override
  String get identifier => 'file';

  final String cacheDirectory;
  final String Function(T) serializer;
  final T Function(String) deserializer;

  Future<File> _getCacheFile(String key) async {
    final directory = Directory(cacheDirectory);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return File('${directory.path}/$key.json');
  }

  @override
  Future<CacheResult<T>> execute(String key) async {
    return await retrieve(key);
  }

  @override
  Future<CacheResult<bool>> store(
    String key,
    T data, {
    Duration? expiration,
  }) async {
    try {
      final file = await _getCacheFile(key);
      final expirationTime = expiration != null
          ? DateTime.now().add(expiration)
          : null;

      final cacheData = CacheData<T>(
        key: key,
        data: data,
        timestamp: DateTime.now(),
        expirationTime: expirationTime,
      );

      await file.writeAsString(jsonEncode(cacheData.toJson()));
      return CacheResult.success(true);
    } catch (e) {
      return CacheResult.failure('Failed to store in file cache: $e');
    }
  }

  @override
  Future<CacheResult<T>> retrieve(String key) async {
    try {
      final file = await _getCacheFile(key);
      if (!await file.exists()) {
        return CacheResult.failure('Key not found in file cache');
      }

      final content = await file.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      final cacheData = CacheData.fromJson(
        json,
        (data) => deserializer(data as String),
      );

      if (cacheData.isExpired) {
        await file.delete();
        return CacheResult.failure('Cache entry expired');
      }

      return CacheResult.success(cacheData.data);
    } catch (e) {
      return CacheResult.failure('Failed to retrieve from file cache: $e');
    }
  }

  @override
  Future<CacheResult<bool>> remove(String key) async {
    try {
      final file = await _getCacheFile(key);
      if (await file.exists()) {
        await file.delete();
        return CacheResult.success(true);
      }
      return CacheResult.success(false);
    } catch (e) {
      return CacheResult.failure('Failed to remove from file cache: $e');
    }
  }

  @override
  Future<CacheResult<bool>> clear() async {
    try {
      final directory = Directory(cacheDirectory);
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
      return CacheResult.success(true);
    } catch (e) {
      return CacheResult.failure('Failed to clear file cache: $e');
    }
  }

  @override
  Future<CacheResult<bool>> exists(String key) async {
    try {
      final file = await _getCacheFile(key);
      if (!await file.exists()) {
        return CacheResult.success(false);
      }

      final content = await file.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      final cacheData = CacheData.fromJson(
        json,
        (data) => deserializer(data as String),
      );

      if (cacheData.isExpired) {
        await file.delete();
        return CacheResult.success(false);
      }

      return CacheResult.success(true);
    } catch (e) {
      return CacheResult.failure('Failed to check existence in file cache: $e');
    }
  }
}

/// Hybrid caching strategy (memory + file)
class HybridCachingStrategy<T> extends CachingStrategy<T> {
  HybridCachingStrategy({
    required this.memoryStrategy,
    required this.fileStrategy,
  });

  @override
  String get identifier => 'hybrid';

  final MemoryCachingStrategy<T> memoryStrategy;
  final FileCachingStrategy<T> fileStrategy;

  @override
  Future<CacheResult<T>> execute(String key) async {
    return await retrieve(key);
  }

  @override
  Future<CacheResult<bool>> store(
    String key,
    T data, {
    Duration? expiration,
  }) async {
    try {
      // Store in both memory and file
      final memoryResult = await memoryStrategy.store(
        key,
        data,
        expiration: expiration,
      );
      final fileResult = await fileStrategy.store(
        key,
        data,
        expiration: expiration,
      );

      if (memoryResult.success && fileResult.success) {
        return CacheResult.success(true);
      } else {
        return CacheResult.failure('Failed to store in hybrid cache');
      }
    } catch (e) {
      return CacheResult.failure('Failed to store in hybrid cache: $e');
    }
  }

  @override
  Future<CacheResult<T>> retrieve(String key) async {
    try {
      // Try memory first
      final memoryResult = await memoryStrategy.retrieve(key);
      if (memoryResult.success) {
        return memoryResult;
      }

      // Fallback to file
      final fileResult = await fileStrategy.retrieve(key);
      if (fileResult.success) {
        // Store in memory for future access
        await memoryStrategy.store(key, fileResult.data!);
        return fileResult;
      }

      return CacheResult.failure('Key not found in hybrid cache');
    } catch (e) {
      return CacheResult.failure('Failed to retrieve from hybrid cache: $e');
    }
  }

  @override
  Future<CacheResult<bool>> remove(String key) async {
    try {
      final memoryResult = await memoryStrategy.remove(key);
      final fileResult = await fileStrategy.remove(key);

      return CacheResult.success(memoryResult.success || fileResult.success);
    } catch (e) {
      return CacheResult.failure('Failed to remove from hybrid cache: $e');
    }
  }

  @override
  Future<CacheResult<bool>> clear() async {
    try {
      final memoryResult = await memoryStrategy.clear();
      final fileResult = await fileStrategy.clear();

      return CacheResult.success(memoryResult.success && fileResult.success);
    } catch (e) {
      return CacheResult.failure('Failed to clear hybrid cache: $e');
    }
  }

  @override
  Future<CacheResult<bool>> exists(String key) async {
    try {
      final memoryResult = await memoryStrategy.exists(key);
      if (memoryResult.success) {
        return memoryResult;
      }

      return await fileStrategy.exists(key);
    } catch (e) {
      return CacheResult.failure(
        'Failed to check existence in hybrid cache: $e',
      );
    }
  }
}

/// Preferences (SharedPreferences) caching strategy for simple key/value data
class PreferencesCachingStrategy extends CachingStrategy<String> {
  PreferencesCachingStrategy();

  @override
  String get identifier => 'preferences';

  Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

  @override
  Future<CacheResult<String>> execute(String key) async {
    return await retrieve(key);
  }

  @override
  Future<CacheResult<bool>> store(
    String key,
    String data, {
    Duration? expiration,
  }) async {
    try {
      final prefs = await _prefs();
      // We store the payload and an optional expiration timestamp
      final bool ok = await prefs.setString(key, data);
      if (expiration != null) {
        final int ts = DateTime.now().add(expiration).millisecondsSinceEpoch;
        await prefs.setInt('${key}__exp', ts);
      } else {
        await prefs.remove('${key}__exp');
      }
      return CacheResult.success(ok);
    } catch (e) {
      return CacheResult.failure('Failed to store in preferences: $e');
    }
  }

  @override
  Future<CacheResult<String>> retrieve(String key) async {
    try {
      final prefs = await _prefs();
      final int? exp = prefs.getInt('${key}__exp');
      if (exp != null &&
          DateTime.now().isAfter(DateTime.fromMillisecondsSinceEpoch(exp))) {
        await prefs.remove(key);
        await prefs.remove('${key}__exp');
        return CacheResult.failure('Cache entry expired');
      }
      final String? value = prefs.getString(key);
      if (value == null)
        return CacheResult.failure('Key not found in preferences');
      return CacheResult.success(value);
    } catch (e) {
      return CacheResult.failure('Failed to retrieve from preferences: $e');
    }
  }

  @override
  Future<CacheResult<bool>> remove(String key) async {
    try {
      final prefs = await _prefs();
      final bool ok = await prefs.remove(key);
      await prefs.remove('${key}__exp');
      return CacheResult.success(ok);
    } catch (e) {
      return CacheResult.failure('Failed to remove from preferences: $e');
    }
  }

  @override
  Future<CacheResult<bool>> clear() async {
    try {
      final prefs = await _prefs();
      // Not clearing all; this strategy cannot safely clear app-wide prefs selectively
      // Return failure to avoid unexpected data loss
      return CacheResult.failure(
        'Clear not supported for preferences strategy',
      );
    } catch (e) {
      return CacheResult.failure('Failed to clear preferences: $e');
    }
  }

  @override
  Future<CacheResult<bool>> exists(String key) async {
    try {
      final prefs = await _prefs();
      final bool hasKey = prefs.containsKey(key);
      if (!hasKey) return CacheResult.success(false);
      final int? exp = prefs.getInt('${key}__exp');
      if (exp != null &&
          DateTime.now().isAfter(DateTime.fromMillisecondsSinceEpoch(exp))) {
        await prefs.remove(key);
        await prefs.remove('${key}__exp');
        return CacheResult.success(false);
      }
      return CacheResult.success(true);
    } catch (e) {
      return CacheResult.failure(
        'Failed to check existence in preferences: $e',
      );
    }
  }
}

/// Cache context for managing caching strategies
class CacheContext<T> {
  CacheContext({required this.defaultStrategy, this.strategies = const []});

  final CachingStrategy<T> defaultStrategy;
  final List<CachingStrategy<T>> strategies;

  /// Store data in cache
  Future<CacheResult<bool>> store(
    String key,
    T data, {
    Duration? expiration,
  }) async {
    final strategy = _selectStrategy(key);
    return await strategy.store(key, data, expiration: expiration);
  }

  /// Retrieve data from cache
  Future<CacheResult<T>> retrieve(String key) async {
    final strategy = _selectStrategy(key);
    return await strategy.retrieve(key);
  }

  /// Remove data from cache
  Future<CacheResult<bool>> remove(String key) async {
    final strategy = _selectStrategy(key);
    return await strategy.remove(key);
  }

  /// Clear all cached data
  Future<CacheResult<bool>> clear() async {
    final strategy = _selectStrategy('');
    return await strategy.clear();
  }

  /// Check if key exists in cache
  Future<CacheResult<bool>> exists(String key) async {
    final strategy = _selectStrategy(key);
    return await strategy.exists(key);
  }

  /// Select caching strategy based on key
  CachingStrategy<T> _selectStrategy(String key) {
    for (final strategy in strategies) {
      if (strategy.canHandle(key)) {
        return strategy;
      }
    }
    return defaultStrategy;
  }

  /// Add a caching strategy
  void addStrategy(CachingStrategy<T> strategy) {
    strategies.add(strategy);
  }
}
