/// Abstract repository providing common functionality for repositories
abstract class AbstractRepository<T, ID> {
  /// Initialize the repository (e.g., database connections)
  Future<void> init();

  /// Dispose of resources
  Future<void> dispose();
}

/// Abstract service providing common functionality for services
abstract class AbstractService<T, ID> {
  /// Initialize the service
  Future<void> init();

  /// Dispose of resources
  Future<void> dispose();
}
