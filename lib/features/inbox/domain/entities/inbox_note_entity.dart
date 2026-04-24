enum InboxNoteStatus { draft, processed, ready, copied, archived }

class InboxNoteEntity {
  final int id;
  final String uuid;
  final String title;
  final String content;
  final String? audioPath;
  final InboxNoteStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int? appliedMacroId;
  final String originalText;
  final String formattedText;
  final String? summary;

  const InboxNoteEntity({
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

  InboxNoteEntity copyWith({
    int? id,
    String? uuid,
    String? title,
    String? content,
    String? audioPath,
    InboxNoteStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? appliedMacroId,
    String? originalText,
    String? formattedText,
    String? summary,
  }) {
    return InboxNoteEntity(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      title: title ?? this.title,
      content: content ?? this.content,
      audioPath: audioPath ?? this.audioPath,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      appliedMacroId: appliedMacroId ?? this.appliedMacroId,
      originalText: originalText ?? this.originalText,
      formattedText: formattedText ?? this.formattedText,
      summary: summary ?? this.summary,
    );
  }
}
