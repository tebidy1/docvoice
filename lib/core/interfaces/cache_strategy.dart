import 'dart:async';

/// Cache strategy interface for intelligent caching
abstract class CacheStrategy<T> {
  /// Check if cached data is still valid
  bool isValid(T cachedData, DateTime cachedAt);
  
  /// Get cache key for entity
  String getCacheKey(String id);
  
  /// Get cache duration
  Duration get cacheDuration;
  
  /// Should cache this entity
  bool shouldCache(T entity);
  
  /// Handle cache miss
  Future<T?> onCacheMiss(String id);
  
  /// Handle cache invalidation
  Future<void> onCacheInvalidated(String id);
}

/// Time-based cache strategy
class TimeBased<T> implements CacheStrategy<T> {
  final Duration _duration;
  
  const TimeBased(this._duration);
  
  @override
  bool isValid(T cachedData, DateTime cachedAt) {
    return DateTime.now().difference(cachedAt) < _duration;
  }
  
  @override
  String getCacheKey(String id) => 'cache_$id';
  
  @override
  Duration get cacheDuration => _duration;
  
  @override
  bool shouldCache(T entity) => true;
  
  @override
  Future<T?> onCacheMiss(String id) async => null;
  
  @override
  Future<void> onCacheInvalidated(String id) async {}
}

/// Usage-based cache strategy
class UsageBased<T> implements CacheStrategy<T> {
  final Duration _baseDuration;
  final int _usageThreshold;
  
  const UsageBased(this._baseDuration, this._usageThreshold);
  
  @override
  bool isValid(T cachedData, DateTime cachedAt) {
    // Extend cache duration based on usage
    final usage = _getUsageCount(cachedData);
    final multiplier = (usage / _usageThreshold).clamp(1.0, 5.0);
    final extendedDuration = Duration(
      milliseconds: (_baseDuration.inMilliseconds * multiplier).round(),
    );
    
    return DateTime.now().difference(cachedAt) < extendedDuration;
  }
  
  @override
  String getCacheKey(String id) => 'usage_cache_$id';
  
  @override
  Duration get cacheDuration => _baseDuration;
  
  @override
  bool shouldCache(T entity) => _getUsageCount(entity) > 0;
  
  @override
  Future<T?> onCacheMiss(String id) async => null;
  
  @override
  Future<void> onCacheInvalidated(String id) async {}
  
  int _getUsageCount(T entity) {
    // Override in specific implementations
    return 0;
  }
}

/// Cache manager interface
abstract class CacheManager<T> {
  /// Get cached entity
  Future<T?> get(String id);
  
  /// Cache entity
  Future<void> put(String id, T entity);
  
  /// Remove from cache
  Future<void> remove(String id);
  
  /// Clear all cache
  Future<void> clear();
  
  /// Get cache statistics
  Future<CacheStats> getStats();
  
  /// Get all cached keys
  Future<List<String>> getKeys();
  
  /// Check if key exists in cache
  Future<bool> containsKey(String id);
  
  /// Get cache size in bytes
  Future<int> getSize();
  
  /// Evict least recently used items
  Future<void> evictLRU(int count);
}

/// Memory-based cache manager implementation
class MemoryCacheManager<T> implements CacheManager<T> {
  final Map<String, _CacheEntry<T>> _cache = {};
  final int _maxSize;
  final Duration _defaultTtl;
  
  MemoryCacheManager({
    int maxSize = 1000,
    Duration defaultTtl = const Duration(minutes: 30),
  }) : _maxSize = maxSize,
       _defaultTtl = defaultTtl;
  
  @override
  Future<T?> get(String id) async {
    final entry = _cache[id];
    if (entry == null) return null;
    
    if (entry.isExpired) {
      _cache.remove(id);
      return null;
    }
    
    entry.updateAccessTime();
    return entry.value;
  }
  
  @override
  Future<void> put(String id, T entity) async {
    if (_cache.length >= _maxSize) {
      await evictLRU(1);
    }
    
    _cache[id] = _CacheEntry(entity, _defaultTtl);
  }
  
  @override
  Future<void> remove(String id) async {
    _cache.remove(id);
  }
  
  @override
  Future<void> clear() async {
    _cache.clear();
  }
  
  @override
  Future<CacheStats> getStats() async {
    int validEntries = 0;
    int expiredEntries = 0;
    
    for (final entry in _cache.values) {
      if (entry.isExpired) {
        expiredEntries++;
      } else {
        validEntries++;
      }
    }
    
    // Clean up expired entries while we're at it
    if (expiredEntries > 0) {
      _cache.removeWhere((key, entry) => entry.isExpired);
    }
    
    return CacheStats(
      hitCount: 0, // Would need to track this separately
      missCount: 0, // Would need to track this separately
      totalRequests: 0, // Would need to track this separately
      hitRate: 0.0, // Would need to track this separately
      cachedItems: validEntries,
      totalMemoryUsage: _cache.length * 100, // Rough estimate
    );
  }
  
  @override
  Future<List<String>> getKeys() async {
    return _cache.keys.toList();
  }
  
  @override
  Future<bool> containsKey(String id) async {
    final entry = _cache[id];
    if (entry == null) return false;
    
    if (entry.isExpired) {
      _cache.remove(id);
      return false;
    }
    
    return true;
  }
  
  @override
  Future<int> getSize() async {
    return _cache.length;
  }
  
  @override
  Future<void> evictLRU(int count) async {
    if (_cache.isEmpty) return;
    
    final entries = _cache.entries.toList();
    entries.sort((a, b) => a.value.lastAccessed.compareTo(b.value.lastAccessed));
    
    for (int i = 0; i < count && i < entries.length; i++) {
      _cache.remove(entries[i].key);
    }
  }
}

/// Cache entry with TTL and access tracking
class _CacheEntry<T> {
  final T value;
  final DateTime createdAt;
  final Duration ttl;
  DateTime lastAccessed;
  
  _CacheEntry(this.value, this.ttl)
      : createdAt = DateTime.now(),
        lastAccessed = DateTime.now();
  
  bool get isExpired => DateTime.now().difference(createdAt) > ttl;
  
  void updateAccessTime() {
    lastAccessed = DateTime.now();
  }
}

/// Cache statistics
class CacheStats {
  final int hitCount;
  final int missCount;
  final int totalRequests;
  final double hitRate;
  final int cachedItems;
  final int totalMemoryUsage;
  
  const CacheStats({
    required this.hitCount,
    required this.missCount,
    required this.totalRequests,
    required this.hitRate,
    required this.cachedItems,
    required this.totalMemoryUsage,
  });
}

/// Write-through cache strategy
class WriteThrough<T> implements CacheStrategy<T> {
  final Duration _duration;
  
  const WriteThrough(this._duration);
  
  @override
  bool isValid(T cachedData, DateTime cachedAt) {
    return DateTime.now().difference(cachedAt) < _duration;
  }
  
  @override
  String getCacheKey(String id) => 'writethrough_$id';
  
  @override
  Duration get cacheDuration => _duration;
  
  @override
  bool shouldCache(T entity) => true;
  
  @override
  Future<T?> onCacheMiss(String id) async => null;
  
  @override
  Future<void> onCacheInvalidated(String id) async {
    // Write-through: data is already in storage
  }
}

/// Write-behind (write-back) cache strategy
class WriteBehind<T> implements CacheStrategy<T> {
  final Duration _duration;
  final Duration _writeDelay;
  final Future<void> Function(String id, T entity) _writeToStorage;
  final Map<String, Timer> _pendingWrites = {};
  
  WriteBehind(this._duration, this._writeDelay, this._writeToStorage);
  
  @override
  bool isValid(T cachedData, DateTime cachedAt) {
    return DateTime.now().difference(cachedAt) < _duration;
  }
  
  @override
  String getCacheKey(String id) => 'writebehind_$id';
  
  @override
  Duration get cacheDuration => _duration;
  
  @override
  bool shouldCache(T entity) => true;
  
  @override
  Future<T?> onCacheMiss(String id) async => null;
  
  @override
  Future<void> onCacheInvalidated(String id) async {
    // Cancel pending write if exists
    _pendingWrites[id]?.cancel();
    _pendingWrites.remove(id);
  }
  
  /// Schedule delayed write to storage
  void scheduleWrite(String id, T entity) {
    // Cancel existing timer if any
    _pendingWrites[id]?.cancel();
    
    // Schedule new write
    _pendingWrites[id] = Timer(_writeDelay, () async {
      await _writeToStorage(id, entity);
      _pendingWrites.remove(id);
    });
  }
}

/// Adaptive cache strategy that adjusts based on usage patterns
class Adaptive<T> implements CacheStrategy<T> {
  final Duration _baseDuration;
  final Map<String, int> _accessCounts = {};
  final Map<String, DateTime> _lastAccess = {};
  
  Adaptive(this._baseDuration);
  
  @override
  bool isValid(T cachedData, DateTime cachedAt) {
    final id = _getEntityId(cachedData);
    final accessCount = _accessCounts[id] ?? 0;
    final lastAccess = _lastAccess[id] ?? cachedAt;
    
    // Extend cache duration based on access frequency and recency
    final frequencyMultiplier = (accessCount / 10).clamp(1.0, 5.0);
    final recencyBonus = DateTime.now().difference(lastAccess).inHours < 1 ? 1.5 : 1.0;
    
    final adjustedDuration = Duration(
      milliseconds: (_baseDuration.inMilliseconds * frequencyMultiplier * recencyBonus).round(),
    );
    
    return DateTime.now().difference(cachedAt) < adjustedDuration;
  }
  
  @override
  String getCacheKey(String id) => 'adaptive_$id';
  
  @override
  Duration get cacheDuration => _baseDuration;
  
  @override
  bool shouldCache(T entity) {
    final id = _getEntityId(entity);
    _recordAccess(id);
    return true;
  }
  
  @override
  Future<T?> onCacheMiss(String id) async {
    _recordAccess(id);
    return null;
  }
  
  @override
  Future<void> onCacheInvalidated(String id) async {
    _accessCounts.remove(id);
    _lastAccess.remove(id);
  }
  
  void _recordAccess(String id) {
    _accessCounts[id] = (_accessCounts[id] ?? 0) + 1;
    _lastAccess[id] = DateTime.now();
  }
  
  String _getEntityId(T entity) {
    // This would need to be implemented based on the entity type
    // For now, return a default value
    return entity.toString();
  }
}

/// Multi-level cache strategy (L1: Memory, L2: Disk)
class MultiLevel<T> implements CacheStrategy<T> {
  final CacheStrategy<T> _l1Strategy;
  final CacheStrategy<T> _l2Strategy;
  final CacheManager<T> _l1Cache;
  final CacheManager<T> _l2Cache;
  
  MultiLevel({
    required CacheStrategy<T> l1Strategy,
    required CacheStrategy<T> l2Strategy,
    required CacheManager<T> l1Cache,
    required CacheManager<T> l2Cache,
  }) : _l1Strategy = l1Strategy,
       _l2Strategy = l2Strategy,
       _l1Cache = l1Cache,
       _l2Cache = l2Cache;
  
  @override
  bool isValid(T cachedData, DateTime cachedAt) {
    return _l1Strategy.isValid(cachedData, cachedAt);
  }
  
  @override
  String getCacheKey(String id) => _l1Strategy.getCacheKey(id);
  
  @override
  Duration get cacheDuration => _l1Strategy.cacheDuration;
  
  @override
  bool shouldCache(T entity) {
    return _l1Strategy.shouldCache(entity) || _l2Strategy.shouldCache(entity);
  }
  
  @override
  Future<T?> onCacheMiss(String id) async {
    // Try L2 cache
    final l2Data = await _l2Cache.get(id);
    if (l2Data != null) {
      // Promote to L1 cache
      await _l1Cache.put(id, l2Data);
      return l2Data;
    }
    
    return null;
  }
  
  @override
  Future<void> onCacheInvalidated(String id) async {
    await _l1Cache.remove(id);
    await _l2Cache.remove(id);
  }
}

/// Repository-specific cache strategies
class RepositoryCacheStrategies {
  /// Cache strategy for frequently accessed macros
  static CacheStrategy<T> macroStrategy<T>() {
    return UsageBased<T>(
      const Duration(hours: 2),
      5, // Cache items accessed 5+ times longer
    );
  }
  
  /// Cache strategy for user settings (long-lived, write-through)
  static CacheStrategy<T> settingsStrategy<T>() {
    return WriteThrough<T>(const Duration(hours: 24));
  }
  
  /// Cache strategy for inbox notes (moderate duration)
  static CacheStrategy<T> inboxNoteStrategy<T>() {
    return TimeBased<T>(const Duration(minutes: 30));
  }
  
  /// Cache strategy for audio uploads (short-lived, high churn)
  static CacheStrategy<T> audioUploadStrategy<T>() {
    return TimeBased<T>(const Duration(minutes: 10));
  }
  
  /// Cache strategy for transcription results (long-lived, rarely change)
  static CacheStrategy<T> transcriptionStrategy<T>() {
    return TimeBased<T>(const Duration(hours: 6));
  }
  
  /// Adaptive strategy for user data
  static CacheStrategy<T> userStrategy<T>() {
    return Adaptive<T>(const Duration(hours: 1));
  }
}