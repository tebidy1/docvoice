import '../interfaces/dto_mapper.dart';
import '../interfaces/settings_service.dart';
import 'enhanced_dto_mapper.dart';
import 'mapping_utils.dart';

/// Data Transfer Object for UserSettings
class UserSettingsDto {
  final Map<String, dynamic> data;
  
  const UserSettingsDto(this.data);
  
  /// Create from JSON response
  factory UserSettingsDto.fromJson(Map<String, dynamic> json) {
    return UserSettingsDto(json);
  }
  
  /// Convert to JSON for API request
  Map<String, dynamic> toJson() => data;
  
  /// Get field value
  T? get<T>(String key) {
    final value = data[key];
    return value is T ? value : null;
  }
}

/// Enhanced mapper for UserSettings DTO with nested structure handling
class UserSettingsDtoMapper extends EnhancedDtoMapper<UserSettings, UserSettingsDto> with CommonFieldTransformers {
  @override
  Map<String, NestedTransformer> get nestedTransformers => {
    ...dateTransformers,
    ...booleanTransformers,
    'settings': SettingsNestedTransformer(),
    'theme': ThemeTransformer(),
    'language': LanguageTransformer(),
    'audio_quality': AudioQualityTransformer(),
  };
  
  @override
  List<String> get requiredFields => [];
  
  @override
  Map<String, dynamic> extractDataFromDto(UserSettingsDto dto) => dto.data;
  
  @override
  Map<String, dynamic> extractDataFromEntity(UserSettings entity) => {
    'settings': entity.all,
    'last_modified': entity.lastModified.toIso8601String(),
    'is_synced': entity.isSynced,
  };
  
  @override
  UserSettings createEntityFromData(Map<String, dynamic> data) {
    // Handle nested settings object or direct settings
    final settingsData = MappingUtils.getNestedValue<Map<String, dynamic>>(data, 'settings') ?? data;
    
    return UserSettings(
      settings: Map<String, dynamic>.from(settingsData),
      lastModified: MappingUtils.getNestedValue<DateTime>(data, 'last_modified') ?? DateTime.now(),
      isSynced: MappingUtils.getNestedValue<bool>(data, 'is_synced') ?? false,
    );
  }
  
  @override
  UserSettingsDto createDtoFromData(Map<String, dynamic> data) {
    return UserSettingsDto(data);
  }
  
  @override
  ValidationResult validateCustomFields(Map<String, dynamic> data, {required bool isDto}) {
    final errors = <String>[];
    
    // Check if we have either a settings object or direct settings data
    final settingsData = MappingUtils.getNestedValue<Map<String, dynamic>>(data, 'settings') ?? data;
    
    if (settingsData.isEmpty) {
      errors.add('Settings data cannot be empty');
    }
    
    // Validate common settings if present
    final theme = MappingUtils.getNestedValue<String>(settingsData, 'theme');
    if (theme != null && !_isValidTheme(theme)) {
      errors.add('Invalid theme value. Must be one of: light, dark, system');
    }
    
    final language = MappingUtils.getNestedValue<String>(settingsData, 'language');
    if (language != null && !_isValidLanguage(language)) {
      errors.add('Invalid language code format');
    }
    
    final audioQuality = MappingUtils.getNestedValue<String>(settingsData, 'audio_quality');
    if (audioQuality != null && !_isValidAudioQuality(audioQuality)) {
      errors.add('Invalid audio_quality value. Must be one of: low, medium, high');
    }
    
    // Validate boolean settings
    final booleanSettings = ['auto_sync', 'offline_mode', 'notification_enabled', 'auto_transcribe'];
    for (final setting in booleanSettings) {
      final value = MappingUtils.getNestedValue(settingsData, setting);
      if (value != null && value is! bool) {
        errors.add('$setting must be a boolean value');
      }
    }
    
    // Validate numeric settings
    final numericSettings = ['max_cache_size', 'sync_interval', 'audio_bitrate'];
    for (final setting in numericSettings) {
      final value = MappingUtils.getNestedValue(settingsData, setting);
      if (value != null && value is! num) {
        errors.add('$setting must be a numeric value');
      }
    }
    
    return errors.isEmpty 
        ? ValidationResult.valid()
        : ValidationResult.invalid(errors);
  }
  
  /// Parse DateTime from string
  DateTime? _parseDateTime(String? dateStr) {
    if (dateStr == null) return null;
    return DateTime.tryParse(dateStr);
  }
  
  /// Validate theme value
  bool _isValidTheme(String theme) {
    const validThemes = ['light', 'dark', 'system'];
    return validThemes.contains(theme.toLowerCase());
  }
  
  /// Validate language code format (basic validation)
  bool _isValidLanguage(String language) {
    // Basic validation for language codes (2-5 characters, letters and hyphens)
    return RegExp(r'^[a-zA-Z]{2,3}(-[a-zA-Z]{2,3})?$').hasMatch(language);
  }
  
  /// Validate audio quality value
  bool _isValidAudioQuality(String quality) {
    const validQualities = ['low', 'medium', 'high'];
    return validQualities.contains(quality.toLowerCase());
  }
}

/// Nested transformer for settings objects
class SettingsNestedTransformer implements NestedTransformer {
  @override
  Map<String, dynamic> transform(dynamic value) {
    if (value == null) return <String, dynamic>{};
    if (value is Map<String, dynamic>) {
      return Map<String, dynamic>.from(value);
    }
    return <String, dynamic>{};
  }
}

/// Theme transformer with validation
class ThemeTransformer implements NestedTransformer {
  @override
  String transform(dynamic value) {
    if (value == null) return 'system';
    final theme = value.toString().toLowerCase();
    const validThemes = ['light', 'dark', 'system'];
    return validThemes.contains(theme) ? theme : 'system';
  }
}

/// Language transformer with validation
class LanguageTransformer implements NestedTransformer {
  @override
  String transform(dynamic value) {
    if (value == null) return 'en';
    final language = value.toString().toLowerCase();
    // Basic validation and normalization
    if (RegExp(r'^[a-zA-Z]{2,3}(-[a-zA-Z]{2,3})?$').hasMatch(language)) {
      return language;
    }
    return 'en'; // Default fallback
  }
}

/// Audio quality transformer with validation
class AudioQualityTransformer implements NestedTransformer {
  @override
  String transform(dynamic value) {
    if (value == null) return 'high';
    final quality = value.toString().toLowerCase();
    const validQualities = ['low', 'medium', 'high'];
    return validQualities.contains(quality) ? quality : 'high';
  }
}