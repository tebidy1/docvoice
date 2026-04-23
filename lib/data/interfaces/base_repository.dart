/// Base repository interface providing common CRUD operations
abstract class BaseRepository<T, ID> {
  /// Create a new entity
  Future<T> create(T entity);

  /// Find entity by ID
  Future<T?> findById(ID id);

  /// Find all entities
  Future<List<T>> findAll();

  /// Update an existing entity
  Future<T> update(ID id, T entity);

  /// Delete entity by ID
  Future<void> delete(ID id);

  /// Check if entity exists by ID
  Future<bool> exists(ID id);
}

/// Base service interface for business logic operations
abstract class BaseService<T, ID> {
  /// Create a new entity
  Future<T> create(T entity);

  /// Find entity by ID
  Future<T?> findById(ID id);

  /// Find all entities
  Future<List<T>> findAll();

  /// Update an existing entity
  Future<T> update(ID id, T entity);

  /// Delete entity by ID
  Future<void> delete(ID id);

  /// Check if entity exists by ID
  Future<bool> exists(ID id);
}
