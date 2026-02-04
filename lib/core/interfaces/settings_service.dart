import 'base_service.dart';

/// Settings service interface for managing user preferences
abstract class SettingsService extends BaseService {
  /// Get user settings
  Future<UserSettings> getSettings();
  
  /// Save user settings
  Future<void> saveSettings(UserSettings settings);
  
  /// Watch for settings changes
  Stream<UserSettings> watchSettings();
  
  /// Sync settings with server
  Future<void> syncSettings();
  
  /// Reset settings to defaults
  Future<void> resetToDefaults();
  
  /// Get setting by key
  Future<T?> getSetting<T>(String key);
  
  /// Set setting by key
  Future<void> setSetting<T>(String key, T value);
  
  /// Remove setting by key
  Future<void> removeSetting(String key);
  
  /// Check if settings are synced
  Future<bool> isSynced();
}

/// User settings model
class UserSettings {
  final Map<String, dynamic> _settings;
  final DateTime lastModified;
  final bool isSynced;
  
  UserSettings({
    Map<String, dynamic>? settings,
    DateTime? lastModified,
    this.isSynced = false,
  }) : _settings = settings ?? {},
       lastModified = lastModified ?? DateTime.now();
  
  /// Get setting value
  T? get<T>(String key) {
    final value = _settings[key];
    return value is T ? value : null;
  }
  
  /// Set setting value
  UserSettings set<T>(String key, T value) {
    final newSettings = Map<String, dynamic>.from(_settings);
    newSettings[key] = value;
    return UserSettings(
      settings: newSettings,
      lastModified: DateTime.now(),
      isSynced: false,
    );
  }
  
  /// Remove setting
  UserSettings remove(String key) {
    final newSettings = Map<String, dynamic>.from(_settings);
    newSettings.remove(key);
    return UserSettings(
      settings: newSettings,
      lastModified: DateTime.now(),
      isSynced: false,
    );
  }
  
  /// Get all settings
  Map<String, dynamic> get all => Map<String, dynamic>.from(_settings);
  
  /// Check if setting exists
  bool contains(String key) => _settings.containsKey(key);
  
  /// Mark as synced
  UserSettings markSynced() {
    return UserSettings(
      settings: _settings,
      lastModified: lastModified,
      isSynced: true,
    );
  }
  
  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'settings': _settings,
      'last_modified': lastModified.toIso8601String(),
      'is_synced': isSynced,
    };
  }
  
  /// Create from JSON
  factory UserSettings.fromJson(Map<String, dynamic> json) {
    return UserSettings(
      settings: json['settings'] ?? {},
      lastModified: json['last_modified'] != null
          ? DateTime.parse(json['last_modified'])
          : DateTime.now(),
      isSynced: json['is_synced'] ?? false,
    );
  }
  
  /// Create default settings
  factory UserSettings.defaults() {
    return UserSettings(
      settings: {
        'theme': 'system',
        'language': 'en',
        'auto_sync': true,
        'offline_mode': false,
        'notification_enabled': true,
        'audio_quality': 'high',
        'auto_transcribe': true,
      },
      isSynced: false,
    );
  }
}