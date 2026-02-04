import '../error/app_error.dart';
import '../interfaces/dto_mapper.dart';

/// Utility class for advanced DTO mapping operations
class MappingUtils {
  /// Recursively transform nested data structures
  static Map<String, dynamic> transformNested(
    Map<String, dynamic> data,
    Map<String, NestedTransformer> transformers,
  ) {
    final result = <String, dynamic>{};
    
    for (final entry in data.entries) {
      final key = entry.key;
      final value = entry.value;
      
      try {
        if (transformers.containsKey(key)) {
          result[key] = transformers[key]!.transform(value);
        } else if (value is Map<String, dynamic>) {
          // Recursively transform nested objects
          result[key] = transformNested(value, transformers);
        } else if (value is List) {
          // Transform lists
          result[key] = _transformList(value, transformers);
        } else {
          // Keep primitive values as-is
          result[key] = value;
        }
      } catch (e) {
        // If transformation fails, keep original value and log error
        result[key] = value;
        throw MappingException(
          'Failed to transform field "$key": ${e.toString()}',
          fieldName: key,
          originalValue: value,
          cause: e,
        );
      }
    }
    
    return result;
  }
  
  /// Transform list values recursively
  static List<dynamic> _transformList(
    List<dynamic> list,
    Map<String, NestedTransformer> transformers,
  ) {
    return list.map((item) {
      if (item is Map<String, dynamic>) {
        return transformNested(item, transformers);
      } else if (item is List) {
        return _transformList(item, transformers);
      } else {
        return item;
      }
    }).toList();
  }
  
  /// Safely extract nested value with path notation (e.g., "user.company.name")
  static T? getNestedValue<T>(Map<String, dynamic> data, String path) {
    final parts = path.split('.');
    dynamic current = data;
    
    for (final part in parts) {
      if (current is Map<String, dynamic>) {
        current = current[part];
      } else {
        return null;
      }
    }
    
    return current is T ? current : null;
  }
  
  /// Safely set nested value with path notation
  static void setNestedValue(
    Map<String, dynamic> data,
    String path,
    dynamic value,
  ) {
    final parts = path.split('.');
    Map<String, dynamic> current = data;
    
    for (int i = 0; i < parts.length - 1; i++) {
      final part = parts[i];
      if (!current.containsKey(part) || current[part] is! Map<String, dynamic>) {
        current[part] = <String, dynamic>{};
      }
      current = current[part] as Map<String, dynamic>;
    }
    
    current[parts.last] = value;
  }
  
  /// Validate required fields in nested structure
  static ValidationResult validateRequiredFields(
    Map<String, dynamic> data,
    List<String> requiredPaths,
  ) {
    final errors = <String>[];
    
    for (final path in requiredPaths) {
      final value = getNestedValue(data, path);
      if (value == null) {
        errors.add('Required field "$path" is missing');
      } else if (value is String && value.isEmpty) {
        errors.add('Required field "$path" cannot be empty');
      }
    }
    
    return errors.isEmpty
        ? ValidationResult.valid()
        : ValidationResult.invalid(errors, context: {'data': data});
  }
  
  /// Flatten nested structure for validation or logging
  static Map<String, dynamic> flatten(
    Map<String, dynamic> data, {
    String prefix = '',
  }) {
    final result = <String, dynamic>{};
    
    for (final entry in data.entries) {
      final key = prefix.isEmpty ? entry.key : '$prefix.${entry.key}';
      final value = entry.value;
      
      if (value is Map<String, dynamic>) {
        result.addAll(flatten(value, prefix: key));
      } else if (value is List) {
        for (int i = 0; i < value.length; i++) {
          final item = value[i];
          if (item is Map<String, dynamic>) {
            result.addAll(flatten(item, prefix: '$key[$i]'));
          } else {
            result['$key[$i]'] = item;
          }
        }
      } else {
        result[key] = value;
      }
    }
    
    return result;
  }
  
  /// Create a deep copy of nested data structure
  static Map<String, dynamic> deepCopy(Map<String, dynamic> data) {
    final result = <String, dynamic>{};
    
    for (final entry in data.entries) {
      final value = entry.value;
      if (value is Map<String, dynamic>) {
        result[entry.key] = deepCopy(value);
      } else if (value is List) {
        result[entry.key] = _deepCopyList(value);
      } else {
        result[entry.key] = value;
      }
    }
    
    return result;
  }
  
  /// Deep copy list with nested structures
  static List<dynamic> _deepCopyList(List<dynamic> list) {
    return list.map((item) {
      if (item is Map<String, dynamic>) {
        return deepCopy(item);
      } else if (item is List) {
        return _deepCopyList(item);
      } else {
        return item;
      }
    }).toList();
  }
}

/// Interface for custom nested transformers
abstract class NestedTransformer {
  dynamic transform(dynamic value);
}

/// Date string transformer
class DateTimeTransformer implements NestedTransformer {
  @override
  DateTime? transform(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) {
      return DateTime.tryParse(value);
    }
    throw ArgumentError('Cannot transform $value to DateTime');
  }
}

/// Enum transformer
class EnumTransformer<T extends Enum> implements NestedTransformer {
  final List<T> values;
  final T defaultValue;
  
  const EnumTransformer(this.values, this.defaultValue);
  
  @override
  T transform(dynamic value) {
    if (value == null) return defaultValue;
    if (value is T) return value;
    
    if (value is String) {
      final enumValue = values.firstWhere(
        (e) => e.toString().split('.').last.toLowerCase() == value.toLowerCase(),
        orElse: () => defaultValue,
      );
      return enumValue;
    }
    
    return defaultValue;
  }
}

/// List transformer for nested objects
class ListTransformer<T> implements NestedTransformer {
  final T Function(dynamic) itemTransformer;
  
  const ListTransformer(this.itemTransformer);
  
  @override
  List<T> transform(dynamic value) {
    if (value == null) return <T>[];
    if (value is! List) throw ArgumentError('Expected List, got ${value.runtimeType}');
    
    return value.map((item) => itemTransformer(item)).toList();
  }
}

/// Mapping exception with detailed context
class MappingException extends AppError {
  final String fieldName;
  final dynamic originalValue;
  final dynamic cause;
  
  MappingException(
    String message, {
    required this.fieldName,
    this.originalValue,
    this.cause,
    String? code,
  }) : super(
    message,
    code: code ?? 'mapping_error',
    context: {
      'field_name': fieldName,
      'original_value': originalValue,
      'cause': cause?.toString(),
    },
  );
  
  @override
  String toString() => 'MappingException: $message (field: $fieldName)';
}

/// Schema version compatibility handler
class SchemaVersionHandler {
  final Map<String, SchemaVersionMigration> _migrations = {};
  
  /// Register a migration for a specific version
  void registerMigration(String version, SchemaVersionMigration migration) {
    _migrations[version] = migration;
  }
  
  /// Apply migrations to transform data from one version to another
  Map<String, dynamic> migrate(
    Map<String, dynamic> data,
    String fromVersion,
    String toVersion,
  ) {
    if (fromVersion == toVersion) return data;
    
    var currentData = MappingUtils.deepCopy(data);
    var currentVersion = fromVersion;
    
    // Apply migrations in sequence
    while (currentVersion != toVersion) {
      final migration = _migrations[currentVersion];
      if (migration == null) {
        throw MappingException(
          'No migration found from version $currentVersion',
          fieldName: 'schema_version',
          originalValue: fromVersion,
        );
      }
      
      try {
        currentData = migration.migrate(currentData);
        currentVersion = migration.targetVersion;
      } catch (e) {
        throw MappingException(
          'Migration failed from $currentVersion to ${migration.targetVersion}',
          fieldName: 'schema_version',
          originalValue: currentData,
          cause: e,
        );
      }
    }
    
    return currentData;
  }
  
  /// Get current schema version from data
  String getSchemaVersion(Map<String, dynamic> data) {
    return data['schema_version']?.toString() ?? '1.0';
  }
  
  /// Set schema version in data
  void setSchemaVersion(Map<String, dynamic> data, String version) {
    data['schema_version'] = version;
  }
}

/// Interface for schema version migrations
abstract class SchemaVersionMigration {
  String get targetVersion;
  Map<String, dynamic> migrate(Map<String, dynamic> data);
}

/// Default migrations for common schema changes
class DefaultMigrations {
  /// Migration from v1.0 to v1.1 - adds new fields with defaults
  static SchemaVersionMigration get v1_0_to_v1_1 => _V1_0_to_V1_1();
  
  /// Migration from v1.1 to v1.2 - renames fields
  static SchemaVersionMigration get v1_1_to_v1_2 => _V1_1_to_V1_2();
}

class _V1_0_to_V1_1 implements SchemaVersionMigration {
  @override
  String get targetVersion => '1.1';
  
  @override
  Map<String, dynamic> migrate(Map<String, dynamic> data) {
    final result = MappingUtils.deepCopy(data);
    
    // Add new fields with defaults
    if (!result.containsKey('created_at')) {
      result['created_at'] = DateTime.now().toIso8601String();
    }
    if (!result.containsKey('updated_at')) {
      result['updated_at'] = result['created_at'];
    }
    
    return result;
  }
}

class _V1_1_to_V1_2 implements SchemaVersionMigration {
  @override
  String get targetVersion => '1.2';
  
  @override
  Map<String, dynamic> migrate(Map<String, dynamic> data) {
    final result = MappingUtils.deepCopy(data);
    
    // Rename fields for consistency
    if (result.containsKey('patient_name')) {
      result['title'] = result['patient_name'];
      result.remove('patient_name');
    }
    if (result.containsKey('raw_text')) {
      result['original_text'] = result['raw_text'];
      result.remove('raw_text');
    }
    
    return result;
  }
}