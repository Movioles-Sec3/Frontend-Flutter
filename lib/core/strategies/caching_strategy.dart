import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
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

  factory CacheData.fromJson(Map<String, dynamic> json, T Function(dynamic) fromJsonT) {
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
  CacheResult({
    required this.success,
    this.data,
    this.error,
  });

  final bool success;
  final T? data;
  final String? error;

  factory CacheResult.success(T data) => CacheResult(success: true, data: data);
  factory CacheResult.failure(String error) => CacheResult(success: false, error: error);
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
  Future<CacheResult<bool>> store(String key, T data, {Duration? expiration}) async {
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
      return CacheResult.failure('Failed to check existence in memory cache: $e');
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
  Future<CacheResult<bool>> store(String key, T data, {Duration? expiration}) async {
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
      final cacheData = CacheData.fromJson(json, (data) => deserializer(data as String));

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
      final cacheData = CacheData.fromJson(json, (data) => deserializer(data as String));

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
  Future<CacheResult<bool>> store(String key, T data, {Duration? expiration}) async {
    try {
      // Store in both memory and file
      final memoryResult = await memoryStrategy.store(key, data, expiration: expiration);
      final fileResult = await fileStrategy.store(key, data, expiration: expiration);
      
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
      return CacheResult.failure('Failed to check existence in hybrid cache: $e');
    }
  }
}

/// Cache context for managing caching strategies
class CacheContext<T> {
  CacheContext({
    required this.defaultStrategy,
    this.strategies = const [],
  });

  final CachingStrategy<T> defaultStrategy;
  final List<CachingStrategy<T>> strategies;

  /// Store data in cache
  Future<CacheResult<bool>> store(String key, T data, {Duration? expiration}) async {
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
