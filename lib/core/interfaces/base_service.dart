/// Base service interface for business logic layer
/// Services orchestrate operations between repositories and UI
abstract class BaseService {
  /// Initialize the service
  Future<void> initialize();
  
  /// Dispose resources
  Future<void> dispose();
  
  /// Check if service is initialized
  bool get isInitialized;
}

/// Service with lifecycle management
mixin ServiceLifecycle {
  bool _isInitialized = false;
  bool _isDisposed = false;
  
  bool get isInitialized => _isInitialized;
  bool get isDisposed => _isDisposed;
  
  /// Mark service as initialized
  void markInitialized() {
    _isInitialized = true;
  }
  
  /// Mark service as disposed
  void markDisposed() {
    _isDisposed = true;
    _isInitialized = false;
  }
  
  /// Ensure service is initialized
  void ensureInitialized() {
    if (!_isInitialized) {
      throw StateError('Service not initialized. Call initialize() first.');
    }
  }
  
  /// Ensure service is not disposed
  void ensureNotDisposed() {
    if (_isDisposed) {
      throw StateError('Service has been disposed.');
    }
  }
}