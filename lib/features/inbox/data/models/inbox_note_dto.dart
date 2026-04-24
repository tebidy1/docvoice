import '../../domain/entities/inbox_note_entity.dart';

class InboxNoteDto {
  final int id;
  final String uuid;
  final String title;
  final String content;
  final String? audioPath;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int? appliedMacroId;
  final String originalText;
  final String formattedText;
  final String? summary;

  const InboxNoteDto({
    required this.id,
    required this.uuid,
    required this.title,
    required this.content,
    this.audioPath,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.appliedMacroId,
    this.originalText = '',
    this.formattedText = '',
    this.summary,
  });

  factory InboxNoteDto.fromJson(Map<String, dynamic> json) {
    return InboxNoteDto(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      uuid: json['uuid'] ?? '',
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      audioPath: json['audio_path'],
      status: json['status'] ?? 'draft',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : DateTime.now(),
      appliedMacroId: json['applied_macro_id'],
      originalText: json['original_text'] ?? '',
      formattedText: json['formatted_text'] ?? '',
      summary: json['summary'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'uuid': uuid,
      'title': title,
      'content': content,
      if (audioPath != null) 'audio_path': audioPath,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      if (appliedMacroId != null) 'applied_macro_id': appliedMacroId,
      'original_text': originalText,
      'formatted_text': formattedText,
      if (summary != null) 'summary': summary,
    };
  }

  InboxNoteEntity toEntity() {
    return InboxNoteEntity(
      id: id,
      uuid: uuid,
      title: title,
      content: content,
      audioPath: audioPath,
      status: _parseStatus(status),
      createdAt: createdAt,
      updatedAt: updatedAt,
      appliedMacroId: appliedMacroId,
      originalText: originalText,
      formattedText: formattedText,
      summary: summary,
    );
  }

  static InboxNoteDto fromEntity(InboxNoteEntity entity) {
    return InboxNoteDto(
      id: entity.id,
      uuid: entity.uuid,
      title: entity.title,
      content: entity.content,
      audioPath: entity.audioPath,
      status: entity.status.name,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
      appliedMacroId: entity.appliedMacroId,
      originalText: entity.originalText,
      formattedText: entity.formattedText,
      summary: entity.summary,
    );
  }

  static InboxNoteStatus _parseStatus(String status) {
    return InboxNoteStatus.values.firstWhere(
      (s) => s.name == status.toLowerCase(),
      orElse: () => InboxNoteStatus.draft,
    );
  }
}
