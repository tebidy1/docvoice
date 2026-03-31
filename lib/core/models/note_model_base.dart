import 'package:flutter/foundation.dart' show kIsWeb;

enum NoteStatus {
  draft, // Initial recording or raw text
  processed, // AI macro applied
  ready, // Confirmed by user, waiting to sync
  copied, // Copied to clipboard/injected (New 3rd State)
  archived // Synced/Completed
}

class NoteModelBase {
  // Use int for universal compatibility
  int id = 0;

  late String uuid; // Sync UUID

  late String title; // E.g. "Recording 1" or Patient Name

  late String content; // The text body

  String? audioPath; // Path to local .m4a file

  late NoteStatus status;

  late DateTime createdAt;
  late DateTime updatedAt;

  // Metadata for AI
  int? appliedMacroId;
  int? suggestedMacroId; // Desktop compatibility

  // API Sync Fields
  String originalText = ''; // Raw text from API/Input
  String formattedText = ''; // Processed text from API/AI
  String? summary; // Brief summary of the note

  // Aliases for Desktop compatibility
  String get rawText => originalText;
  set rawText(String value) => originalText = value;

  String get patientName => title;
  set patientName(String value) => title = value;

  // Default constructor
  NoteModelBase();

  // ============================================
  // JSON Serialization
  // ============================================

  /// Convert from JSON (API response)
  factory NoteModelBase.fromJson(Map<String, dynamic> json) {
    final note = NoteModelBase();
    note.id = json['id'] is int
        ? json['id']
        : int.parse((json['id'] ?? 0).toString());
    note.uuid = json['uuid'] ?? '';

    // Support both naming conventions
    note.title = json['title'] ?? json['patient_name'] ?? '';
    note.originalText = json['original_text'] ?? json['raw_text'] ?? '';
    note.formattedText = json['formatted_text'] ?? '';

    note.content = json['content'] ?? note.formattedText;
    if (note.content.isEmpty) note.content = note.originalText;

    note.summary = json['summary'];
    note.audioPath = json['audio_path'];
    note.status = _parseStatus(json['status']);

    note.createdAt = json['created_at'] != null
        ? DateTime.parse(json['created_at'])
        : DateTime.now();
    note.updatedAt = json['updated_at'] != null
        ? DateTime.parse(json['updated_at'])
        : (note.createdAt);

    note.appliedMacroId = json['applied_macro_id'] is int
        ? json['applied_macro_id']
        : int.tryParse(json['applied_macro_id']?.toString() ?? '');
        
    note.suggestedMacroId = json['suggested_macro_id'] is int
        ? json['suggested_macro_id']
        : int.tryParse(json['suggested_macro_id']?.toString() ?? '');

    return note;
  }

  /// Convert to JSON (for API requests)
  Map<String, dynamic> toJson() {
    return {
      if (id > 0) 'id': id,
      'uuid': uuid,
      'title': title,
      'patient_name': title, // Send both for compatibility
      'content': content,
      'original_text': originalText,
      'raw_text': originalText, // Send both
      if (formattedText.isNotEmpty) 'formatted_text': formattedText,
      if (audioPath != null) 'audio_path': audioPath,
      'status': status.toString().split('.').last,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      if (appliedMacroId != null) 'applied_macro_id': appliedMacroId,
      if (suggestedMacroId != null) 'suggested_macro_id': suggestedMacroId,
      if (summary != null) 'summary': summary,
    };
  }

  /// Parse status from string
  static NoteStatus _parseStatus(dynamic status) {
    if (status == null) return NoteStatus.draft;

    final statusStr = status.toString().toLowerCase();
    switch (statusStr) {
      case 'draft':
        return NoteStatus.draft;
      case 'processed':
        return NoteStatus.processed;
      case 'ready':
        return NoteStatus.ready;
      case 'copied':
        return NoteStatus.copied;
      case 'archived':
        return NoteStatus.archived;
      default:
        return NoteStatus.draft;
    }
  }
}
