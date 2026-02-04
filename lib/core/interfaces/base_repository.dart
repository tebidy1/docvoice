/// Base repository interface providing standard CRUD operations
/// This interface abstracts data access from business logic
abstract class BaseRepository<T> {
  /// Get all entities
  Future<List<T>> getAll();
  
  /// Get entity by ID
  Future<T?> getById(String id);
  
  /// Create new entity
  Future<T> create(T entity);
  
  /// Update existing entity
  Future<T> update(T entity);
  
  /// Delete entity by ID
  Future<void> delete(String id);
  
  /// Watch for changes to entities (reactive stream)
  Stream<List<T>> watch();
  
  /// Check if entity exists
  Future<bool> exists(String id);
  
  /// Get entities with pagination
  Future<List<T>> getPaginated({int page = 1, int limit = 20});
  
  /// Search entities by query
  Future<List<T>> search(String query);
}