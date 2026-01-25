import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

/// Strategy for cache usage
enum CacheStrategy {
  /// Try cache first, fallback to network
  cacheFirst,

  /// Try network first, fallback to cache
  networkFirst,

  /// Use cache only (no network call)
  cacheOnly,

  /// Use network only (no cache)
  networkOnly,
}

/// Manager for caching API responses with expiry support
///
/// Provides different caching strategies and automatic expiry handling.
///
/// Example usage:
/// ```dart
/// final cacheManager = CacheManager();
/// await cacheManager.save('notes', notesData, expiry: Duration(hours: 1));
/// final cached = await cacheManager.get<List<Note>>('notes', fromJson: ...);
/// ```
class CacheManager {
  static final CacheManager _instance = CacheManager._internal();
  factory CacheManager() => _instance;
  CacheManager._internal();

  SharedPreferences? _prefs;

  /// Initialize the cache manager
  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  // ============================================
  // Basic Cache Operations
  // ============================================

  /// Save data to cache with optional expiry
  ///
  /// [key] - Unique key for the cached data
  /// [data] - Data to cache (must be JSON serializable)
  /// [expiry] - Optional expiry duration
  ///
  /// Returns true if successful
  Future<bool> save(String key, dynamic data, {Duration? expiry}) async {
    await init();

    final cacheData = {
      'data': data,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'expiry': expiry?.inMilliseconds,
    };

    try {
      final success = await _prefs!.setString(key, jsonEncode(cacheData));
      if (success) {
        debugPrint(
            '💾 Cached: $key ${expiry != null ? "(expires in ${expiry.inMinutes}m)" : ""}');
      }
      return success;
    } catch (e) {
      debugPrint('❌ Error caching $key: $e');
      return false;
    }
  }

  /// Get data from cache
  ///
  /// [key] - The cache key
  /// [fromJson] - Function to deserialize the cached data
  ///
  /// Returns the cached data or null if not found/expired
  Future<T?> get<T>(String key, {required T Function(dynamic) fromJson}) async {
    await init();

    final cacheString = _prefs!.getString(key);
    if (cacheString == null) {
      debugPrint('📭 Cache miss: $key');
      return null;
    }

    try {
      final cacheData = jsonDecode(cacheString);

      // Check expiry
      if (cacheData['expiry'] != null) {
        final timestamp = cacheData['timestamp'] as int;
        final expiry = cacheData['expiry'] as int;
        final now = DateTime.now().millisecondsSinceEpoch;

        if (now - timestamp > expiry) {
          debugPrint('⏰ Cache expired: $key');
          await remove(key);
          return null;
        }
      }

      debugPrint('✅ Cache hit: $key');
      return fromJson(cacheData['data']);
    } catch (e) {
      debugPrint('❌ Error reading cache $key: $e');
      await remove(key); // Remove corrupted cache
      return null;
    }
  }

  /// Remove a specific item from cache
  Future<bool> remove(String key) async {
    await init();
    return await _prefs!.remove(key);
  }

  /// Clear all cached data
  Future<bool> clearAll() async {
    await init();
    debugPrint('🗑️ Clearing all cache');
    return await _prefs!.clear();
  }

  /// Check if a key exists in cache and is not expired
  Future<bool> has(String key) async {
    await init();

    final cacheString = _prefs!.getString(key);
    if (cacheString == null) return false;

    try {
      final cacheData = jsonDecode(cacheString);

      // Check expiry
      if (cacheData['expiry'] != null) {
        final timestamp = cacheData['timestamp'] as int;
        final expiry = cacheData['expiry'] as int;
        final now = DateTime.now().millisecondsSinceEpoch;

        if (now - timestamp > expiry) {
          await remove(key);
          return false;
        }
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  // ============================================
  // Advanced Cache Operations
  // ============================================

  /// Fetch data with a specific cache strategy
  ///
  /// [cacheKey] - Key for caching
  /// [apiCall] - Function that makes the API call
  /// [fromJson] - Function to deserialize cached data
  /// [toJson] - Function to serialize data for caching
  /// [strategy] - Cache strategy to use
  /// [cacheExpiry] - Optional cache expiry duration
  ///
  /// Returns the data from cache or API based on strategy
  Future<T> fetchWithStrategy<T>({
    required String cacheKey,
    required Future<T> Function() apiCall,
    required T Function(dynamic) fromJson,
    required dynamic Function(T) toJson,
    CacheStrategy strategy = CacheStrategy.cacheFirst,
    Duration? cacheExpiry,
  }) async {
    switch (strategy) {
      case CacheStrategy.cacheFirst:
        return await _cacheFirstStrategy(
          cacheKey: cacheKey,
          apiCall: apiCall,
          fromJson: fromJson,
          toJson: toJson,
          cacheExpiry: cacheExpiry,
        );

      case CacheStrategy.networkFirst:
        return await _networkFirstStrategy(
          cacheKey: cacheKey,
          apiCall: apiCall,
          fromJson: fromJson,
          toJson: toJson,
          cacheExpiry: cacheExpiry,
        );

      case CacheStrategy.cacheOnly:
        return await _cacheOnlyStrategy(
          cacheKey: cacheKey,
          fromJson: fromJson,
        );

      case CacheStrategy.networkOnly:
        return await _networkOnlyStrategy(
          cacheKey: cacheKey,
          apiCall: apiCall,
          toJson: toJson,
          cacheExpiry: cacheExpiry,
        );
    }
  }

  /// Cache-first strategy: Try cache, fallback to API
  Future<T> _cacheFirstStrategy<T>({
    required String cacheKey,
    required Future<T> Function() apiCall,
    required T Function(dynamic) fromJson,
    required dynamic Function(T) toJson,
    Duration? cacheExpiry,
  }) async {
    // Try cache first
    final cached = await get<T>(cacheKey, fromJson: fromJson);
    if (cached != null) {
      debugPrint('📦 Using cached data for $cacheKey');
      return cached;
    }

    // Fallback to API
    debugPrint('🌐 Fetching fresh data for $cacheKey');
    final data = await apiCall();
    await save(cacheKey, toJson(data), expiry: cacheExpiry);
    return data;
  }

  /// Network-first strategy: Try API, fallback to cache
  Future<T> _networkFirstStrategy<T>({
    required String cacheKey,
    required Future<T> Function() apiCall,
    required T Function(dynamic) fromJson,
    required dynamic Function(T) toJson,
    Duration? cacheExpiry,
  }) async {
    try {
      // Try API first
      debugPrint('🌐 Fetching fresh data for $cacheKey');
      final data = await apiCall();
      await save(cacheKey, toJson(data), expiry: cacheExpiry);
      return data;
    } catch (e) {
      debugPrint('⚠️ API failed, trying cache for $cacheKey');
      // Fallback to cache
      final cached = await get<T>(cacheKey, fromJson: fromJson);
      if (cached != null) {
        debugPrint('📦 Using stale cached data for $cacheKey');
        return cached;
      }
      rethrow;
    }
  }

  /// Cache-only strategy: Use cache, throw if not available
  Future<T> _cacheOnlyStrategy<T>({
    required String cacheKey,
    required T Function(dynamic) fromJson,
  }) async {
    final cached = await get<T>(cacheKey, fromJson: fromJson);
    if (cached == null) {
      throw Exception('No cached data available for $cacheKey');
    }
    return cached;
  }

  /// Network-only strategy: Always fetch from API
  Future<T> _networkOnlyStrategy<T>({
    required String cacheKey,
    required Future<T> Function() apiCall,
    required dynamic Function(T) toJson,
    Duration? cacheExpiry,
  }) async {
    debugPrint('🌐 Fetching fresh data for $cacheKey (network-only)');
    final data = await apiCall();
    await save(cacheKey, toJson(data), expiry: cacheExpiry);
    return data;
  }

  /// Get cache statistics
  Future<Map<String, dynamic>> getStats() async {
    await init();

    final keys = _prefs!.getKeys();
    int totalItems = keys.length;
    int expiredItems = 0;

    for (final key in keys) {
      final hasKey = await has(key);
      if (!hasKey) expiredItems++;
    }

    return {
      'totalItems': totalItems,
      'expiredItems': expiredItems,
      'validItems': totalItems - expiredItems,
    };
  }
}
