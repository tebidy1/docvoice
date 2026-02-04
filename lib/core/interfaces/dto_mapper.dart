/// Base interface for Data Transfer Object mapping
/// Handles transformation between API responses and domain models
abstract class DtoMapper<TEntity, TDto> {
  /// Transform DTO to domain entity
  TEntity toEntity(TDto dto);
  
  /// Transform domain entity to DTO
  TDto fromEntity(TEntity entity);
  
  /// Transform list of DTOs to domain entities
  List<TEntity> toEntityList(List<TDto> dtos) {
    return dtos.map((dto) => toEntity(dto)).toList();
  }
  
  /// Transform list of domain entities to DTOs
  List<TDto> fromEntityList(List<TEntity> entities) {
    return entities.map((entity) => fromEntity(entity)).toList();
  }
}

/// Validation result for DTO mapping
class ValidationResult {
  final bool isValid;
  final List<String> errors;
  final Map<String, dynamic>? context;
  
  const ValidationResult({
    required this.isValid,
    this.errors = const [],
    this.context,
  });
  
  factory ValidationResult.valid() => const ValidationResult(isValid: true);
  
  factory ValidationResult.invalid(List<String> errors, {Map<String, dynamic>? context}) {
    return ValidationResult(
      isValid: false,
      errors: errors,
      context: context,
    );
  }
}

/// Enhanced DTO mapper with validation
abstract class ValidatedDtoMapper<TEntity, TDto> extends DtoMapper<TEntity, TDto> {
  /// Validate DTO before transformation
  ValidationResult validateDto(TDto dto);
  
  /// Validate entity before transformation
  ValidationResult validateEntity(TEntity entity);
  
  /// Transform DTO to entity with validation
  TEntity toEntityValidated(TDto dto) {
    final validation = validateDto(dto);
    if (!validation.isValid) {
      throw DtoValidationException(
        'DTO validation failed: ${validation.errors.join(', ')}',
        validation.errors,
        validation.context,
      );
    }
    return toEntity(dto);
  }
  
  /// Transform entity to DTO with validation
  TDto fromEntityValidated(TEntity entity) {
    final validation = validateEntity(entity);
    if (!validation.isValid) {
      throw DtoValidationException(
        'Entity validation failed: ${validation.errors.join(', ')}',
        validation.errors,
        validation.context,
      );
    }
    return fromEntity(entity);
  }
}

/// Exception thrown when DTO validation fails
class DtoValidationException implements Exception {
  final String message;
  final List<String> errors;
  final Map<String, dynamic>? context;
  
  const DtoValidationException(this.message, this.errors, [this.context]);
  
  @override
  String toString() => 'DtoValidationException: $message';
}