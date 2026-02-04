import 'dart:convert';
import '../interfaces/dto_mapper.dart';
import '../../models/inbox_note.dart';
import 'enhanced_dto_mapper.dart';
import 'mapping_utils.dart';

/// Data Transfer Object for InboxNote
class InboxNoteDto {
  final Map<String, dynamic> data;
  
  const InboxNoteDto(this.data);
  
  /// Create from JSON response
  factory InboxNoteDto.fromJson(Map<String, dynamic> json) {
    return InboxNoteDto(json);
  }
  
  /// Convert to JSON for API request
  Map<String, dynamic> toJson() => data;
  
  /// Get field value
  T? get<T>(String key) {
    final value = data[key];
    return value is T ? value : null;
  }
}

/// Enhanced mapper for InboxNote DTO with nested structure handling
class InboxNoteDtoMapper extends EnhancedDtoMapper<InboxNote, InboxNoteDto> with CommonFieldTransformers {
  @override
  Map<String, NestedTransformer> get nestedTransformers => {
    ...dateTransformers,
    ...integerTransformers,
    'status': EnumTransformer(NoteStatus.values, NoteStatus.draft),
    'metadata': MetadataTransformer(),
  };
  
  @override
  List<String> get requiredFields => ['uuid'];
  
  @override
  Map<String, dynamic> extractDataFromDto(InboxNoteDto dto) => dto.data;
  
  @override
  Map<String, dynamic> extractDataFromEntity(InboxNote entity) => {
    if (entity.id > 0) 'id': entity.id,
    'uuid': entity.uuid,
    'title': entity.title,
    'patient_name': entity.title, // Send both for compatibility
    'content': entity.content,
    'original_text': entity.originalText,
    'raw_text': entity.originalText, // Send both
    if (entity.formattedText.isNotEmpty) 'formatted_text': entity.formattedText,
    if (entity.summary != null) 'summary': entity.summary,
    if (entity.audioPath != null) 'audio_path': entity.audioPath,
    'status': entity.status.toString().split('.').last,
    'created_at': entity.createdAt.toIso8601String(),
    'updated_at': entity.updatedAt.toIso8601String(),
    if (entity.appliedMacroId != null) 'applied_macro_id': entity.appliedMacroId,
    if (entity.suggestedMacroId != null) 'suggested_macro_id': entity.suggestedMacroId,
  };
  
  @override
  InboxNote createEntityFromData(Map<String, dynamic> data) {
    final note = InboxNote();
    note.id = MappingUtils.getNestedValue<int>(data, 'id') ?? 0;
    note.uuid = MappingUtils.getNestedValue<String>(data, 'uuid') ?? '';
    
    // Handle title with fallback to patient_name
    note.title = MappingUtils.getNestedValue<String>(data, 'title') ?? 
                 MappingUtils.getNestedValue<String>(data, 'patient_name') ?? '';
    
    note.content = MappingUtils.getNestedValue<String>(data, 'content') ?? '';
    
    // Handle original text with fallback to raw_text
    note.originalText = MappingUtils.getNestedValue<String>(data, 'original_text') ?? 
                       MappingUtils.getNestedValue<String>(data, 'raw_text') ?? '';
    
    note.formattedText = MappingUtils.getNestedValue<String>(data, 'formatted_text') ?? '';
    note.summary = MappingUtils.getNestedValue<String>(data, 'summary');
    note.audioPath = MappingUtils.getNestedValue<String>(data, 'audio_path');
    note.appliedMacroId = MappingUtils.getNestedValue<String>(data, 'applied_macro_id');
    note.suggestedMacroId = MappingUtils.getNestedValue<int>(data, 'suggested_macro_id');
    
    // Parse status with enhanced enum transformer
    note.status = MappingUtils.getNestedValue<NoteStatus>(data, 'status') ?? NoteStatus.draft;
    
    // Handle dates with enhanced transformers
    note.createdAt = MappingUtils.getNestedValue<DateTime>(data, 'created_at') ?? DateTime.now();
    note.updatedAt = MappingUtils.getNestedValue<DateTime>(data, 'updated_at') ?? note.createdAt;
    
    return note;
  }
  
  @override
  InboxNoteDto createDtoFromData(Map<String, dynamic> data) {
    return InboxNoteDto(data);
  }
  
  @override
  ValidationResult validateCustomFields(Map<String, dynamic> data, {required bool isDto}) {
    final errors = <String>[];
    
    final title = MappingUtils.getNestedValue<String>(data, 'title') ?? 
                  MappingUtils.getNestedValue<String>(data, 'patient_name');
    if (title == null || title.isEmpty) {
      errors.add('Title is required');
    } else if (title.length > 200) {
      errors.add('Title must be 200 characters or less');
    }
    
    final content = MappingUtils.getNestedValue<String>(data, 'content');
    final originalText = MappingUtils.getNestedValue<String>(data, 'original_text') ?? 
                        MappingUtils.getNestedValue<String>(data, 'raw_text');
    
    if ((content == null || content.isEmpty) && 
        (originalText == null || originalText.isEmpty)) {
      errors.add('Either content or original text is required');
    }
    
    // Validate UUID format if present
    final uuid = MappingUtils.getNestedValue<String>(data, 'uuid');
    if (uuid != null && uuid.isNotEmpty && !_isValidUuid(uuid)) {
      errors.add('Invalid UUID format');
    }
    
    // Validate content lengths
    if (content != null && content.length > 50000) {
      errors.add('Content must be 50000 characters or less');
    }
    
    if (originalText != null && originalText.length > 50000) {
      errors.add('Original text must be 50000 characters or less');
    }
    
    final formattedText = MappingUtils.getNestedValue<String>(data, 'formatted_text');
    if (formattedText != null && formattedText.length > 50000) {
      errors.add('Formatted text must be 50000 characters or less');
    }
    
    final summary = MappingUtils.getNestedValue<String>(data, 'summary');
    if (summary != null && summary.length > 1000) {
      errors.add('Summary must be 1000 characters or less');
    }
    
    // Validate audio path format if present
    final audioPath = MappingUtils.getNestedValue<String>(data, 'audio_path');
    if (audioPath != null && audioPath.isNotEmpty && !_isValidAudioPath(audioPath)) {
      errors.add('Invalid audio path format');
    }
    
    return errors.isEmpty 
        ? ValidationResult.valid()
        : ValidationResult.invalid(errors);
  }
  
  /// Parse status from string
  NoteStatus _parseStatus(String? status) {
    if (status == null) return NoteStatus.draft;
    
    final statusStr = status.toLowerCase();
    switch (statusStr) {
      case 'draft':
        return NoteStatus.draft;
      case 'processed':
        return NoteStatus.processed;
      case 'ready':
        return NoteStatus.ready;
      case 'archived':
        return NoteStatus.archived;
      default:
        return NoteStatus.draft;
    }
  }
  
  /// Validate UUID format (basic validation)
  bool _isValidUuid(String uuid) {
    return RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(uuid);
  }
  
  /// Validate status value
  bool _isValidStatus(String status) {
    const validStatuses = ['draft', 'processed', 'ready', 'archived'];
    return validStatuses.contains(status.toLowerCase());
  }
  
  /// Validate audio path format
  bool _isValidAudioPath(String path) {
    // Basic validation for audio file paths
    const validExtensions = ['.mp3', '.wav', '.m4a', '.aac', '.flac'];
    return validExtensions.any((ext) => path.toLowerCase().endsWith(ext));
  }
}

/// Nested transformer for metadata objects
class MetadataTransformer implements NestedTransformer {
  @override
  Map<String, dynamic>? transform(dynamic value) {
    if (value == null) return null;
    if (value is Map<String, dynamic>) {
      // Ensure metadata is properly structured
      return Map<String, dynamic>.from(value);
    }
    if (value is String) {
      // Try to parse JSON string
      try {
        final decoded = jsonDecode(value);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
      } catch (e) {
        // If parsing fails, return null
        return null;
      }
    }
    return null;
  }
}