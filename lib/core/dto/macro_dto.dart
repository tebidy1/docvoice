import '../interfaces/dto_mapper.dart';
import '../../models/macro.dart';
import 'enhanced_dto_mapper.dart';
import 'mapping_utils.dart';

/// Data Transfer Object for Macro
class MacroDto {
  final Map<String, dynamic> data;
  
  const MacroDto(this.data);
  
  /// Create from JSON response
  factory MacroDto.fromJson(Map<String, dynamic> json) {
    return MacroDto(json);
  }
  
  /// Convert to JSON for API request
  Map<String, dynamic> toJson() => data;
  
  /// Get field value
  T? get<T>(String key) {
    final value = data[key];
    return value is T ? value : null;
  }
}

/// Enhanced mapper for Macro DTO with nested structure handling
class MacroDtoMapper extends EnhancedDtoMapper<Macro, MacroDto> with CommonFieldTransformers {
  @override
  Map<String, NestedTransformer> get nestedTransformers => {
    ...dateTransformers,
    ...booleanTransformers,
    ...integerTransformers,
    'category': CategoryTransformer(),
  };
  
  @override
  List<String> get requiredFields => ['trigger', 'content'];
  
  @override
  Map<String, dynamic> extractDataFromDto(MacroDto dto) => dto.data;
  
  @override
  Map<String, dynamic> extractDataFromEntity(Macro entity) => {
    'id': entity.id,
    'trigger': entity.trigger,
    'content': entity.content,
    'category': entity.category,
    'is_favorite': entity.isFavorite,
    'usage_count': entity.usageCount,
    'is_ai_macro': entity.isAiMacro,
    if (entity.aiInstruction != null) 'ai_instruction': entity.aiInstruction,
    if (entity.lastUsed != null) 'last_used': entity.lastUsed!.toIso8601String(),
    'created_at': entity.createdAt.toIso8601String(),
  };
  
  @override
  Macro createEntityFromData(Map<String, dynamic> data) {
    final macro = Macro();
    macro.id = MappingUtils.getNestedValue<int>(data, 'id') ?? 0;
    macro.trigger = MappingUtils.getNestedValue<String>(data, 'trigger') ?? '';
    macro.content = MappingUtils.getNestedValue<String>(data, 'content') ?? '';
    macro.category = MappingUtils.getNestedValue<String>(data, 'category') ?? 'General';
    macro.isFavorite = MappingUtils.getNestedValue<bool>(data, 'is_favorite') ?? false;
    macro.usageCount = MappingUtils.getNestedValue<int>(data, 'usage_count') ?? 0;
    macro.isAiMacro = MappingUtils.getNestedValue<bool>(data, 'is_ai_macro') ?? false;
    macro.aiInstruction = MappingUtils.getNestedValue<String>(data, 'ai_instruction');
    
    // Handle dates with enhanced transformers
    macro.lastUsed = MappingUtils.getNestedValue<DateTime>(data, 'last_used');
    macro.createdAt = MappingUtils.getNestedValue<DateTime>(data, 'created_at') ?? DateTime.now();
    
    return macro;
  }
  
  @override
  MacroDto createDtoFromData(Map<String, dynamic> data) {
    return MacroDto(data);
  }
  
  @override
  ValidationResult validateCustomFields(Map<String, dynamic> data, {required bool isDto}) {
    final errors = <String>[];
    
    final trigger = MappingUtils.getNestedValue<String>(data, 'trigger');
    if (trigger != null && trigger.length > 100) {
      errors.add('Trigger must be 100 characters or less');
    }
    
    final content = MappingUtils.getNestedValue<String>(data, 'content');
    if (content != null && content.length > 5000) {
      errors.add('Content must be 5000 characters or less');
    }
    
    // Validate category
    final category = MappingUtils.getNestedValue<String>(data, 'category');
    if (category != null && category.length > 50) {
      errors.add('Category must be 50 characters or less');
    }
    
    // Validate usage count
    final usageCount = MappingUtils.getNestedValue<int>(data, 'usage_count');
    if (usageCount != null && usageCount < 0) {
      errors.add('Usage count cannot be negative');
    }
    
    // Validate AI instruction length
    final aiInstruction = MappingUtils.getNestedValue<String>(data, 'ai_instruction');
    if (aiInstruction != null && aiInstruction.length > 1000) {
      errors.add('AI instruction must be 1000 characters or less');
    }
    
    // Validate trigger format (no special characters that could cause issues)
    if (trigger != null && !_isValidTrigger(trigger)) {
      errors.add('Trigger contains invalid characters');
    }
    
    return errors.isEmpty 
        ? ValidationResult.valid()
        : ValidationResult.invalid(errors);
  }
  
  /// Validate trigger format
  bool _isValidTrigger(String trigger) {
    // Allow alphanumeric, spaces, and common punctuation
    return RegExp(r'^[a-zA-Z0-9\s\.\,\!\?\-\_\(\)]+$').hasMatch(trigger);
  }
}

/// Nested transformer for category normalization
class CategoryTransformer implements NestedTransformer {
  @override
  String transform(dynamic value) {
    if (value == null) return 'General';
    final category = value.toString().trim();
    if (category.isEmpty) return 'General';
    
    // Normalize category name (capitalize first letter)
    return category[0].toUpperCase() + category.substring(1).toLowerCase();
  }
}