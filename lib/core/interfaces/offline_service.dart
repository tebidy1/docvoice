import 'base_service.dart';

/// Offline service interface for managing offline functionality
abstract class OfflineService extends BaseService {
  /// Check if device is online
  Future<bool> isOnline();
  
  /// Watch connectivity status
  Stream<bool> watchConnectivity();
  
  /// Queue operation for offline execution
  Future<void> queueOperation(OfflineOperation operation);
  
  /// Get queued operations
  Future<List<OfflineOperation>> getQueuedOperations();
  
  /// Process sync queue when online
  Future<void> processSyncQueue();
  
  /// Cache essential data for offline use
  Future<void> cacheEssentialData();
  
  /// Clear offline cache
  Future<void> clearCache();
  
  /// Get cache size
  Future<int> getCacheSize();
  
  /// Check if data is cached
  Future<bool> isCached(String key);
  
  /// Get cached data
  Future<T?> getCachedData<T>(String key);
  
  /// Cache data
  Future<void> cacheData<T>(String key, T data);
}

/// Offline operation
class OfflineOperation {
  final String id;
  final String type;
  final Map<String, dynamic> data;
  final DateTime createdAt;
  final int retryCount;
  final int maxRetries;
  final OperationPriority priority;
  
  const OfflineOperation({
    required this.id,
    required this.type,
    required this.data,
    required this.createdAt,
    this.retryCount = 0,
    this.maxRetries = 3,
    this.priority = OperationPriority.normal,
  });
  
  /// Create retry operation
  OfflineOperation retry() {
    return OfflineOperation(
      id: id,
      type: type,
      data: data,
      createdAt: createdAt,
      retryCount: retryCount + 1,
      maxRetries: maxRetries,
      priority: priority,
    );
  }
  
  /// Check if operation can be retried
  bool get canRetry => retryCount < maxRetries;
  
  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'data': data,
      'created_at': createdAt.toIso8601String(),
      'retry_count': retryCount,
      'max_retries': maxRetries,
      'priority': priority.toString(),
    };
  }
  
  /// Create from JSON
  factory OfflineOperation.fromJson(Map<String, dynamic> json) {
    return OfflineOperation(
      id: json['id'],
      type: json['type'],
      data: json['data'] ?? {},
      createdAt: DateTime.parse(json['created_at']),
      retryCount: json['retry_count'] ?? 0,
      maxRetries: json['max_retries'] ?? 3,
      priority: OperationPriority.values.firstWhere(
        (p) => p.toString() == json['priority'],
        orElse: () => OperationPriority.normal,
      ),
    );
  }
}

/// Operation priority
enum OperationPriority {
  low,
  normal,
  high,
  critical
}

/// Sync conflict resolution strategy
enum ConflictResolution {
  useLocal,
  useRemote,
  merge,
  askUser
}

/// Sync conflict
class SyncConflict {
  final String id;
  final String type;
  final Map<String, dynamic> localData;
  final Map<String, dynamic> remoteData;
  final DateTime localModified;
  final DateTime remoteModified;
  
  const SyncConflict({
    required this.id,
    required this.type,
    required this.localData,
    required this.remoteData,
    required this.localModified,
    required this.remoteModified,
  });
  
  /// Check if remote is newer
  bool get isRemoteNewer => remoteModified.isAfter(localModified);
  
  /// Check if local is newer
  bool get isLocalNewer => localModified.isAfter(remoteModified);
}