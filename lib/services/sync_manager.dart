import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'api_service.dart';

/// Type of sync operation
enum SyncOperation {
  create,
  update,
  delete,
  patch,
}

/// Represents a single operation to be synced
class SyncItem {
  final String id;
  final String endpoint;
  final SyncOperation operation;
  final Map<String, dynamic>? data;
  final DateTime timestamp;
  final int retryCount;

  SyncItem({
    required this.id,
    required this.endpoint,
    required this.operation,
    this.data,
    required this.timestamp,
    this.retryCount = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'endpoint': endpoint,
        'operation': operation.toString(),
        'data': data,
        'timestamp': timestamp.toIso8601String(),
        'retryCount': retryCount,
      };

  factory SyncItem.fromJson(Map<String, dynamic> json) => SyncItem(
        id: json['id'],
        endpoint: json['endpoint'],
        operation: SyncOperation.values
            .firstWhere((e) => e.toString() == json['operation']),
        data: json['data'],
        timestamp: DateTime.parse(json['timestamp']),
        retryCount: json['retryCount'] ?? 0,
      );

  /// Create a copy with updated retry count
  SyncItem copyWithRetry() => SyncItem(
        id: id,
        endpoint: endpoint,
        operation: operation,
        data: data,
        timestamp: timestamp,
        retryCount: retryCount + 1,
      );
}

/// Manager for syncing offline operations when connection is restored
///
/// Queues operations performed offline and automatically syncs them
/// when internet connection is available.
///
/// Example usage:
/// ```dart
/// final syncManager = SyncManager();
/// await syncManager.addToQueue(SyncItem(
///   id: 'note_123',
///   endpoint: '/inbox-notes',
///   operation: SyncOperation.create,
///   data: noteData,
///   timestamp: DateTime.now(),
/// ));
/// ```
class SyncManager {
  static final SyncManager _instance = SyncManager._internal();
  factory SyncManager() => _instance;
  SyncManager._internal();

  static const String _queueKey = 'sync_queue';
  static const int _maxRetries = 3;

  SharedPreferences? _prefs;
  bool _isSyncing = false;
  bool _isInitialized = false;

  final ApiService _apiService = ApiService();

  /// Callbacks for sync events
  Function(int queueSize)? onQueueChanged;
  Function(SyncItem item, bool success)? onItemSynced;
  Function(String error)? onSyncError;

  /// Initialize the sync manager and start listening to connectivity
  Future<void> init() async {
    if (_isInitialized) return;

    _prefs ??= await SharedPreferences.getInstance();
    _isInitialized = true;

    // Listen to connectivity changes
    Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> results) {
      if (results.isNotEmpty &&
          results.any((result) => result != ConnectivityResult.none)) {
        debugPrint('🌐 Connection restored, starting sync...');
        syncAll();
      }
    });

    // Try to sync on init if connected
    final List<ConnectivityResult> results =
        await Connectivity().checkConnectivity();
    if (results.isNotEmpty &&
        results.any((result) => result != ConnectivityResult.none)) {
      syncAll();
    }

    debugPrint('✅ SyncManager initialized');
  }

  // ============================================
  // Queue Management
  // ============================================

  /// Add an operation to the sync queue
  Future<void> addToQueue(SyncItem item) async {
    await init();

    final queue = await _getQueue();
    queue.add(item);
    await _saveQueue(queue);

    debugPrint('📝 Added to sync queue: ${item.operation} ${item.endpoint}');
    onQueueChanged?.call(queue.length);

    // Try to sync immediately if connected
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult != ConnectivityResult.none) {
      syncAll();
    }
  }

  /// Get the current sync queue
  Future<List<SyncItem>> _getQueue() async {
    await init();

    final queueString = _prefs!.getString(_queueKey);
    if (queueString == null) return [];

    try {
      final List<dynamic> queueJson = jsonDecode(queueString);
      return queueJson.map((item) => SyncItem.fromJson(item)).toList();
    } catch (e) {
      debugPrint('❌ Error reading sync queue: $e');
      return [];
    }
  }

  /// Save the sync queue
  Future<void> _saveQueue(List<SyncItem> queue) async {
    await init();

    final queueJson = queue.map((item) => item.toJson()).toList();
    await _prefs!.setString(_queueKey, jsonEncode(queueJson));
  }

  /// Get the current queue size
  Future<int> getQueueSize() async {
    final queue = await _getQueue();
    return queue.length;
  }

  /// Clear the entire sync queue
  Future<void> clearQueue() async {
    await init();
    await _prefs!.remove(_queueKey);
    debugPrint('🗑️ Sync queue cleared');
    onQueueChanged?.call(0);
  }

  // ============================================
  // Sync Operations
  // ============================================

  /// Sync all pending operations
  Future<void> syncAll() async {
    if (_isSyncing) {
      debugPrint('⏳ Sync already in progress, skipping...');
      return;
    }

    _isSyncing = true;

    try {
      final queue = await _getQueue();

      if (queue.isEmpty) {
        debugPrint('✅ Sync queue is empty');
        return;
      }

      debugPrint('🔄 Starting sync of ${queue.length} items...');

      final failedItems = <SyncItem>[];
      int successCount = 0;

      for (final item in queue) {
        try {
          await _syncItem(item);
          successCount++;
          onItemSynced?.call(item, true);
          debugPrint('✅ Synced: ${item.operation} ${item.endpoint}');
        } catch (e) {
          debugPrint(
              '❌ Failed to sync: ${item.operation} ${item.endpoint} - $e');

          // Retry logic
          if (item.retryCount < _maxRetries) {
            failedItems.add(item.copyWithRetry());
            debugPrint('🔄 Will retry (${item.retryCount + 1}/$_maxRetries)');
          } else {
            debugPrint('⚠️ Max retries reached, discarding item');
            onSyncError?.call(
                'Failed to sync ${item.endpoint} after $_maxRetries attempts');
          }

          onItemSynced?.call(item, false);
        }
      }

      // Save failed items back to queue
      await _saveQueue(failedItems);
      onQueueChanged?.call(failedItems.length);

      debugPrint(
          '✅ Sync complete: $successCount succeeded, ${failedItems.length} failed');
    } finally {
      _isSyncing = false;
    }
  }

  /// Sync a single item
  Future<void> _syncItem(SyncItem item) async {
    switch (item.operation) {
      case SyncOperation.create:
        await _apiService.post(item.endpoint, body: item.data);
        break;

      case SyncOperation.update:
        await _apiService.put(item.endpoint, body: item.data);
        break;

      case SyncOperation.delete:
        await _apiService.delete(item.endpoint);
        break;

      case SyncOperation.patch:
        await _apiService.patch(item.endpoint, body: item.data);
        break;
    }
  }

  /// Check if currently syncing
  bool get isSyncing => _isSyncing;

  /// Check if there are pending items
  Future<bool> hasPendingItems() async {
    final size = await getQueueSize();
    return size > 0;
  }

  /// Get sync queue status
  Future<Map<String, dynamic>> getStatus() async {
    final queue = await _getQueue();

    return {
      'queueSize': queue.length,
      'isSyncing': _isSyncing,
      'oldestItem':
          queue.isNotEmpty ? queue.first.timestamp.toIso8601String() : null,
      'newestItem':
          queue.isNotEmpty ? queue.last.timestamp.toIso8601String() : null,
    };
  }
}
