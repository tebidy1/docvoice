import 'base_repository.dart';
import 'settings_service.dart';

/// Repository interface for UserSettings entities
abstract class SettingsRepository extends BaseRepository<UserSettings> {
  /// Get settings by user ID
  Future<UserSettings?> getByUserId(String userId);
  
  /// Get current user settings
  Future<UserSettings> getCurrentUserSettings();
  
  /// Save current user settings
  Future<void> saveCurrentUserSettings(UserSettings settings);
  
  /// Get settings by key pattern
  Future<Map<String, dynamic>> getSettingsByPattern(String keyPattern);
  
  /// Get default settings
  Future<UserSettings> getDefaultSettings();
  
  /// Reset settings to defaults
  Future<void> resetToDefaults(String userId);
  
  /// Merge settings with defaults
  Future<UserSettings> mergeWithDefaults(UserSettings settings);
  
  /// Get settings history
  Future<List<UserSettings>> getSettingsHistory(String userId, {int limit = 10});
  
  /// Backup settings
  Future<String> backupSettings(String userId);
  
  /// Restore settings from backup
  Future<void> restoreSettings(String userId, String backupData);
  
  /// Get settings that need sync
  Future<List<UserSettings>> getUnsyncedSettings();
  
  /// Mark settings as synced
  Future<void> markAsSynced(String userId);
  
  /// Get settings conflicts
  Future<List<SettingsConflict>> getConflicts(String userId);
  
  /// Resolve settings conflict
  Future<void> resolveConflict(String userId, SettingsConflict conflict, SettingsConflictResolution resolution);
  
  /// Watch settings changes for user
  Stream<UserSettings> watchUserSettings(String userId);
  
  /// Get settings sync status
  Future<SettingsSyncStatus> getSyncStatus(String userId);
}

/// Settings conflict information
class SettingsConflict {
  final String userId;
  final String settingKey;
  final dynamic localValue;
  final dynamic remoteValue;
  final DateTime localModified;
  final DateTime remoteModified;
  final ConflictType type;
  
  const SettingsConflict({
    required this.userId,
    required this.settingKey,
    required this.localValue,
    required this.remoteValue,
    required this.localModified,
    required this.remoteModified,
    required this.type,
  });
  
  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'setting_key': settingKey,
      'local_value': localValue,
      'remote_value': remoteValue,
      'local_modified': localModified.toIso8601String(),
      'remote_modified': remoteModified.toIso8601String(),
      'type': type.toString().split('.').last,
    };
  }
  
  /// Create from JSON
  factory SettingsConflict.fromJson(Map<String, dynamic> json) {
    return SettingsConflict(
      userId: json['user_id'],
      settingKey: json['setting_key'],
      localValue: json['local_value'],
      remoteValue: json['remote_value'],
      localModified: DateTime.parse(json['local_modified']),
      remoteModified: DateTime.parse(json['remote_modified']),
      type: ConflictType.values.firstWhere(
        (e) => e.toString().split('.').last == json['type'],
        orElse: () => ConflictType.valueConflict,
      ),
    );
  }
}

/// Types of settings conflicts
enum ConflictType {
  valueConflict,    // Different values for same key
  deletionConflict, // One side deleted, other modified
  typeConflict,     // Different data types for same key
}

/// Conflict resolution strategies
enum SettingsConflictResolution {
  useLocal,         // Keep local value
  useRemote,        // Use remote value
  merge,            // Attempt to merge values
  askUser,          // Prompt user for decision
}

/// Settings synchronization status
class SettingsSyncStatus {
  final String userId;
  final bool isSynced;
  final DateTime? lastSyncTime;
  final int pendingChanges;
  final List<String> conflictKeys;
  final SyncState state;
  
  const SettingsSyncStatus({
    required this.userId,
    required this.isSynced,
    this.lastSyncTime,
    required this.pendingChanges,
    required this.conflictKeys,
    required this.state,
  });
  
  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'is_synced': isSynced,
      'last_sync_time': lastSyncTime?.toIso8601String(),
      'pending_changes': pendingChanges,
      'conflict_keys': conflictKeys,
      'state': state.toString().split('.').last,
    };
  }
  
  /// Create from JSON
  factory SettingsSyncStatus.fromJson(Map<String, dynamic> json) {
    return SettingsSyncStatus(
      userId: json['user_id'],
      isSynced: json['is_synced'] ?? false,
      lastSyncTime: json['last_sync_time'] != null
          ? DateTime.parse(json['last_sync_time'])
          : null,
      pendingChanges: json['pending_changes'] ?? 0,
      conflictKeys: List<String>.from(json['conflict_keys'] ?? []),
      state: SyncState.values.firstWhere(
        (e) => e.toString().split('.').last == json['state'],
        orElse: () => SyncState.idle,
      ),
    );
  }
}

/// Synchronization states
enum SyncState {
  idle,       // No sync in progress
  syncing,    // Sync in progress
  conflict,   // Conflicts need resolution
  error,      // Sync failed
  offline,    // Device is offline
}