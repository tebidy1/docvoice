import '../error/app_error.dart';
import '../interfaces/dto_mapper.dart';
import 'mapping_utils.dart';
import 'mapping_error_reporter.dart';

/// Enhanced DTO mapper with nested structure handling and error management
abstract class EnhancedDtoMapper<TEntity, TDto> extends ValidatedDtoMapper<TEntity, TDto> {
  /// Schema version handler for API compatibility
  final SchemaVersionHandler _schemaHandler = SchemaVersionHandler();
  
  /// Error reporter for detailed error tracking
  final MappingErrorReporter _errorReporter = MappingErrorReporter();
  
  /// Current schema version supported by this mapper
  String get currentSchemaVersion => '1.2';
  
  /// Nested transformers for complex field mapping
  Map<String, NestedTransformer> get nestedTransformers => {};
  
  /// Required field paths for validation
  List<String> get requiredFields => [];
  
  /// Initialize the mapper with default migrations
  EnhancedDtoMapper() {
    _initializeDefaultMigrations();
  }
  
  /// Transform DTO to entity with enhanced error handling
  @override
  TEntity toEntity(TDto dto) {
    try {
      final data = extractDataFromDto(dto);
      final processedData = _processIncomingData(data);
      return createEntityFromData(processedData);
    } catch (e) {
      final report = _errorReporter.createReport(
        e,
        'toEntity',
        runtimeType.toString(),
        dto,
        additionalContext: getErrorContext(e, dto),
      );
      _errorReporter.reportError(report);
      
      if (e is MappingException) {
        rethrow;
      }
      throw MappingException(
        'Failed to convert DTO to entity: ${e.toString()}',
        fieldName: 'root',
        originalValue: dto,
        cause: e,
      );
    }
  }
  
  /// Transform entity to DTO with enhanced error handling
  @override
  TDto fromEntity(TEntity entity) {
    try {
      final data = extractDataFromEntity(entity);
      final processedData = _processOutgoingData(data);
      return createDtoFromData(processedData);
    } catch (e) {
      final report = _errorReporter.createReport(
        e,
        'fromEntity',
        runtimeType.toString(),
        entity,
        additionalContext: getErrorContext(e, entity),
      );
      _errorReporter.reportError(report);
      
      if (e is MappingException) {
        rethrow;
      }
      throw MappingException(
        'Failed to convert entity to DTO: ${e.toString()}',
        fieldName: 'root',
        originalValue: entity,
        cause: e,
      );
    }
  }
  
  /// Enhanced validation with nested structure support
  @override
  ValidationResult validateDto(TDto dto) {
    try {
      final data = extractDataFromDto(dto);
      return _validateData(data, isDto: true);
    } catch (e) {
      return ValidationResult.invalid(
        ['Failed to validate DTO: ${e.toString()}'],
        context: {'dto': dto, 'error': e.toString()},
      );
    }
  }
  
  /// Enhanced validation with nested structure support
  @override
  ValidationResult validateEntity(TEntity entity) {
    try {
      final data = extractDataFromEntity(entity);
      return _validateData(data, isDto: false);
    } catch (e) {
      return ValidationResult.invalid(
        ['Failed to validate entity: ${e.toString()}'],
        context: {'entity': entity, 'error': e.toString()},
      );
    }
  }
  
  /// Transform list with detailed error reporting
  @override
  List<TEntity> toEntityList(List<TDto> dtos) {
    final results = <TEntity>[];
    final errors = <String>[];
    
    for (int i = 0; i < dtos.length; i++) {
      try {
        results.add(toEntity(dtos[i]));
      } catch (e) {
        final error = 'Item $i: ${e.toString()}';
        errors.add(error);
        
        final report = _errorReporter.createReport(
          e,
          'toEntityList',
          runtimeType.toString(),
          dtos[i],
          fieldName: 'list_item_$i',
          additionalContext: {'list_index': i, 'list_length': dtos.length},
        );
        _errorReporter.reportError(report);
      }
    }
    
    if (errors.isNotEmpty) {
      throw MappingException(
        'Failed to convert ${errors.length} items in list',
        fieldName: 'list_items',
        originalValue: dtos,
        cause: errors.join('; '),
      );
    }
    
    return results;
  }
  
  /// Transform list with detailed error reporting
  @override
  List<TDto> fromEntityList(List<TEntity> entities) {
    final results = <TDto>[];
    final errors = <String>[];
    
    for (int i = 0; i < entities.length; i++) {
      try {
        results.add(fromEntity(entities[i]));
      } catch (e) {
        final error = 'Item $i: ${e.toString()}';
        errors.add(error);
        
        final report = _errorReporter.createReport(
          e,
          'fromEntityList',
          runtimeType.toString(),
          entities[i],
          fieldName: 'list_item_$i',
          additionalContext: {'list_index': i, 'list_length': entities.length},
        );
        _errorReporter.reportError(report);
      }
    }
    
    if (errors.isNotEmpty) {
      throw MappingException(
        'Failed to convert ${errors.length} items in list',
        fieldName: 'list_items',
        originalValue: entities,
        cause: errors.join('; '),
      );
    }
    
    return results;
  }
  
  /// Extract raw data from DTO (to be implemented by subclasses)
  Map<String, dynamic> extractDataFromDto(TDto dto);
  
  /// Extract raw data from entity (to be implemented by subclasses)
  Map<String, dynamic> extractDataFromEntity(TEntity entity);
  
  /// Create entity from processed data (to be implemented by subclasses)
  TEntity createEntityFromData(Map<String, dynamic> data);
  
  /// Create DTO from processed data (to be implemented by subclasses)
  TDto createDtoFromData(Map<String, dynamic> data);
  
  /// Custom validation logic (to be implemented by subclasses)
  ValidationResult validateCustomFields(Map<String, dynamic> data, {required bool isDto}) {
    return ValidationResult.valid();
  }
  
  /// Process incoming data (DTO -> Entity)
  Map<String, dynamic> _processIncomingData(Map<String, dynamic> data) {
    try {
      // Handle schema version compatibility
      final schemaVersion = _schemaHandler.getSchemaVersion(data);
      final migratedData = _schemaHandler.migrate(data, schemaVersion, currentSchemaVersion);
      
      // Apply nested transformations
      final transformedData = MappingUtils.transformNested(migratedData, nestedTransformers);
      
      // Set current schema version
      _schemaHandler.setSchemaVersion(transformedData, currentSchemaVersion);
      
      return transformedData;
    } catch (e) {
      // If migration or transformation fails, try to continue with original data
      // but log the issue
      final report = _errorReporter.createReport(
        e,
        '_processIncomingData',
        runtimeType.toString(),
        data,
        fieldName: 'data_processing',
      );
      _errorReporter.reportError(report);
      
      // Return original data as fallback
      return data;
    }
  }
  
  /// Process outgoing data (Entity -> DTO)
  Map<String, dynamic> _processOutgoingData(Map<String, dynamic> data) {
    // Apply nested transformations (reverse)
    final transformedData = MappingUtils.transformNested(data, _getReverseTransformers());
    
    // Set current schema version
    _schemaHandler.setSchemaVersion(transformedData, currentSchemaVersion);
    
    return transformedData;
  }
  
  /// Validate data with enhanced error reporting
  ValidationResult _validateData(Map<String, dynamic> data, {required bool isDto}) {
    final errors = <String>[];
    final context = <String, dynamic>{};
    
    try {
      // Validate required fields
      final requiredValidation = MappingUtils.validateRequiredFields(data, requiredFields);
      if (!requiredValidation.isValid) {
        errors.addAll(requiredValidation.errors);
      }
      
      // Custom validation
      final customValidation = validateCustomFields(data, isDto: isDto);
      if (!customValidation.isValid) {
        errors.addAll(customValidation.errors);
        if (customValidation.context != null) {
          context.addAll(customValidation.context!);
        }
      }
      
      // Add flattened data for debugging
      context['flattened_data'] = MappingUtils.flatten(data);
      
    } catch (e) {
      errors.add('Validation error: ${e.toString()}');
      context['validation_exception'] = e.toString();
    }
    
    return errors.isEmpty
        ? ValidationResult.valid()
        : ValidationResult.invalid(errors, context: context);
  }
  
  /// Get reverse transformers for outgoing data
  Map<String, NestedTransformer> _getReverseTransformers() {
    // For now, return the same transformers
    // Subclasses can override this for bidirectional transformations
    return nestedTransformers;
  }
  
  /// Initialize default schema migrations
  void _initializeDefaultMigrations() {
    _schemaHandler.registerMigration('1.0', DefaultMigrations.v1_0_to_v1_1);
    _schemaHandler.registerMigration('1.1', DefaultMigrations.v1_1_to_v1_2);
  }
  
  /// Register custom migration
  void registerMigration(String fromVersion, SchemaVersionMigration migration) {
    _schemaHandler.registerMigration(fromVersion, migration);
  }
  
  /// Get detailed error information for debugging
  Map<String, dynamic> getErrorContext(dynamic error, dynamic originalData) {
    return {
      'error_type': error.runtimeType.toString(),
      'error_message': error.toString(),
      'original_data_type': originalData.runtimeType.toString(),
      'timestamp': DateTime.now().toIso8601String(),
      'mapper_type': runtimeType.toString(),
      'schema_version': currentSchemaVersion,
      if (originalData is Map<String, dynamic>)
        'flattened_original': MappingUtils.flatten(originalData),
    };
  }
  
  /// Get error statistics for this mapper
  MappingErrorStatistics getErrorStatistics() {
    return _errorReporter.getStatistics();
  }
  
  /// Get recent errors for this mapper
  List<MappingErrorReport> getRecentErrors({int limit = 10}) {
    return _errorReporter.getErrorsForMapper(runtimeType.toString(), limit: limit);
  }
  
  /// Clear error history for this mapper
  void clearErrorHistory() {
    _errorReporter.clearHistory();
  }
}

/// Mixin for common field transformations
mixin CommonFieldTransformers {
  /// Get common transformers for date fields
  Map<String, NestedTransformer> get dateTransformers => {
    'created_at': DateTimeTransformer(),
    'updated_at': DateTimeTransformer(),
    'last_used': DateTimeTransformer(),
    'last_seen': DateTimeTransformer(),
    'last_modified': DateTimeTransformer(),
  };
  
  /// Get transformers for boolean fields
  Map<String, NestedTransformer> get booleanTransformers => {
    'is_favorite': BooleanTransformer(),
    'is_ai_macro': BooleanTransformer(),
    'is_online': BooleanTransformer(),
    'is_synced': BooleanTransformer(),
    'is_active': BooleanTransformer(),
    'auto_sync': BooleanTransformer(),
    'offline_mode': BooleanTransformer(),
    'notification_enabled': BooleanTransformer(),
    'auto_transcribe': BooleanTransformer(),
  };
  
  /// Get transformers for integer fields
  Map<String, NestedTransformer> get integerTransformers => {
    'id': IntegerTransformer(),
    'company_id': IntegerTransformer(),
    'usage_count': IntegerTransformer(),
    'users_count': IntegerTransformer(),
    'suggested_macro_id': IntegerTransformer(),
  };
}

/// Boolean transformer that handles various input types
class BooleanTransformer implements NestedTransformer {
  @override
  bool transform(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is int) return value != 0;
    if (value is String) {
      final lower = value.toLowerCase();
      return lower == 'true' || lower == '1' || lower == 'yes';
    }
    return false;
  }
}

/// Integer transformer that handles various input types
class IntegerTransformer implements NestedTransformer {
  @override
  int? transform(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) return parsed;
      // Try parsing as double first, then convert to int
      final doubleValue = double.tryParse(value);
      return doubleValue?.toInt();
    }
    return null;
  }
}

/// String transformer that handles null values
class StringTransformer implements NestedTransformer {
  final String defaultValue;
  
  const StringTransformer([this.defaultValue = '']);
  
  @override
  String transform(dynamic value) {
    if (value == null) return defaultValue;
    return value.toString();
  }
}