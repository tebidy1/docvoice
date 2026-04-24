class GeneratedOutput {
  int? id;
  int? macroId;
  String? title;
  String? content;
  int orderIndex = 0;

  Map<String, dynamic>? macro;
  DateTime? createdAt;
  DateTime? updatedAt;
  int? inboxNoteId;

  GeneratedOutput({
    this.id,
    this.macroId,
    this.title,
    this.content,
    this.orderIndex = 0,
    this.macro,
    this.createdAt,
    this.updatedAt,
    this.inboxNoteId,
  });

  factory GeneratedOutput.fromJson(Map<String, dynamic> json) {
    return GeneratedOutput(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? ''),
      macroId: json['macro_id'] is int
          ? json['macro_id']
          : int.tryParse(json['macro_id']?.toString() ?? ''),
      title: json['title'] as String?,
      content: json['content'] as String?,
      orderIndex: json['order_index'] is int
          ? json['order_index']
          : int.tryParse(json['order_index']?.toString() ?? '0') ?? 0,
      macro: json['macro'] != null
          ? Map<String, dynamic>.from(json['macro'])
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'])
          : null,
      inboxNoteId: json['inbox_note_id'] is int
          ? json['inbox_note_id']
          : int.tryParse(json['inbox_note_id']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (macroId != null) 'macro_id': macroId,
      if (title != null) 'title': title,
      if (content != null) 'content': content,
      'order_index': orderIndex,
    };
  }
}
