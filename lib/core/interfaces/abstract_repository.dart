import 'dart:async';
import 'base_repository.dart';
import 'cache_strategy.dart';

/// Abstract base repository providing common functionality
/// This class provides default implementations for common repository operations
abstract class AbstractRepository<T> implements BaseRepository<T> {
  final CacheManager<T>? _cacheManager;
  final CacheStrategy<T>? _cacheStrategy;
  
  AbstractRepository({
    CacheManager<T>? cacheManager,
    CacheStrategy<T>? cacheStrategy,
  }) : _cacheManager = cacheManager,
       _cacheStrategy = cacheStrategy;
  
  /// Protected access to cache manager for subclasses
  CacheManager<T>? get cacheManager => _cacheManager;
  
  /// Protected access to cache strategy for subclasses
  CacheStrategy<T>? get cacheStrategy => _cacheStrategy;
  
  /// Get entity from cache or data source
  @override
  Future<T?> getById(String id) async {
    // Try cache first if available
    if (_cacheManager != null && _cacheStrategy != null) {
      final cached = await _cacheManager!.get(id);
      if (cached != null && _cacheStrategy!.isValid(cached, DateTime.now())) {
        return cached;
      }
    }
    
    // Fetch from data source
    final entity = await fetchById(id);
    
    // Cache the result if available
    if (entity != null && _cacheManager != null && _cacheStrategy != null) {
      if (_cacheStrategy!.shouldCache(entity)) {
        await _cacheManager!.put(id, entity);
      }
    }
    
    return entity;
  }
  
  /// Check if entity exists
  @override
  Future<bool> exists(String id) async {
    final entity = await getById(id);
    return entity != null;
  }
  
  /// Get entities with pagination
  @override
  Future<List<T>> getPaginated({int page = 1, int limit = 20}) async {
    final offset = (page - 1) * limit;
    return await fetchPaginated(offset: offset, limit: limit);
  }
  
  /// Create entity with validation
  @override
  Future<T> create(T entity) async {
    await validateEntity(entity);
    final created = await createEntity(entity);
    
    // Invalidate cache if needed
    if (_cacheManager != null) {
      await _cacheManager!.clear();
    }
    
    return created;
  }
  
  /// Update entity with validation
  @override
  Future<T> update(T entity) async {
    await validateEntity(entity);
    final updated = await updateEntity(entity);
    
    // Update cache if available
    if (_cacheManager != null && _cacheStrategy != null) {
      final id = getEntityId(entity);
      if (_cacheStrategy!.shouldCache(updated)) {
        await _cacheManager!.put(id, updated);
      } else {
        await _cacheManager!.remove(id);
      }
    }
    
    return updated;
  }
  
  /// Delete entity
  @override
  Future<void> delete(String id) async {
    await deleteEntity(id);
    
    // Remove from cache
    if (_cacheManager != null) {
      await _cacheManager!.remove(id);
    }
  }
  
  /// Watch for changes (default implementation using polling)
  @override
  Stream<List<T>> watch() {
    return Stream.periodic(
      const Duration(seconds: 5),
      (_) => getAll(),
    ).asyncMap((future) => future);
  }
  
  // Abstract methods that must be implemented by concrete classes
  
  /// Fetch entity by ID from data source
  Future<T?> fetchById(String id);
  
  /// Fetch all entities from data source
  Future<List<T>> fetchAll();
  
  /// Fetch entities with pagination from data source
  Future<List<T>> fetchPaginated({required int offset, required int limit});
  
  /// Search entities in data source
  Future<List<T>> searchEntities(String query);
  
  /// Create entity in data source
  Future<T> createEntity(T entity);
  
  /// Update entity in data source
  Future<T> updateEntity(T entity);
  
  /// Delete entity from data source
  Future<void> deleteEntity(String id);
  
  /// Get entity ID for caching purposes
  String getEntityId(T entity);
  
  /// Validate entity before create/update
  Future<void> validateEntity(T entity) async {
    // Default implementation does nothing
    // Override in concrete classes for validation
  }
  
  // Default implementations that delegate to abstract methods
  
  @override
  Future<List<T>> getAll() => fetchAll();
  
  @override
  Future<List<T>> search(String query) => searchEntities(query);
}

/// Abstract cached repository with built-in caching support
abstract class AbstractCachedRepository<T> extends AbstractRepository<T> {
  AbstractCachedRepository({
    required super.cacheManager,
    required super.cacheStrategy,
  });
  
  /// Get all entities with caching
  @override
  Future<List<T>> getAll() async {
    const cacheKey = 'all_entities';
    
    // Try cache first
    if (_cacheManager != null) {
      final cached = await _cacheManager!.get(cacheKey);
      if (cached != null && cached is List<T> && _cacheStrategy!.isValid(cached as T, DateTime.now())) {
        return cached;
      }
    }
    
    // Fetch from data source
    final entities = await fetchAll();
    
    // Cache the result
    if (_cacheManager != null && _cacheStrategy != null && entities.isNotEmpty) {
      // Note: This is a simplified approach. In practice, you might want to cache individual entities
      // rather than the entire list, or use a different caching strategy for collections
      await _cacheManager!.clear(); // Clear old cache
      for (final entity in entities) {
        if (_cacheStrategy!.shouldCache(entity)) {
          await _cacheManager!.put(getEntityId(entity), entity);
        }
      }
    }
    
    return entities;
  }
}

/// Abstract API repository for REST API-based data sources
abstract class AbstractApiRepository<T> extends AbstractRepository<T> {
  final String baseUrl;
  final Map<String, String> defaultHeaders;
  
  AbstractApiRepository({
    required this.baseUrl,
    this.defaultHeaders = const {},
    super.cacheManager,
    super.cacheStrategy,
  });
  
  /// Get API endpoint for this repository
  String get endpoint;
  
  /// Convert JSON to entity
  T fromJson(Map<String, dynamic> json);
  
  /// Convert entity to JSON
  Map<String, dynamic> toJson(T entity);
  
  /// Get HTTP headers for requests
  Map<String, String> getHeaders() {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      ...defaultHeaders,
    };
  }
  
  /// Build full URL for endpoint
  String buildUrl(String path) {
    final cleanBase = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final cleanPath = path.startsWith('/') ? path : '/$path';
    return '$cleanBase$endpoint$cleanPath';
  }
}

/// Abstract local repository for local storage-based data sources
abstract class AbstractLocalRepository<T> extends AbstractRepository<T> {
  final String storageKey;
  
  AbstractLocalRepository({
    required this.storageKey,
    super.cacheManager,
    super.cacheStrategy,
  });
  
  /// Convert entity to storable format
  Map<String, dynamic> toStorable(T entity);
  
  /// Convert storable format to entity
  T fromStorable(Map<String, dynamic> data);
  
  /// Get storage key for entity
  String getStorageKey(String id) => '${storageKey}_$id';
  
  /// Get all storage keys
  Future<List<String>> getAllStorageKeys();
  
  /// Read from local storage
  Future<Map<String, dynamic>?> readFromStorage(String key);
  
  /// Write to local storage
  Future<void> writeToStorage(String key, Map<String, dynamic> data);
  
  /// Delete from local storage
  Future<void> deleteFromStorage(String key);
}