class MacroLocalModel {
  int id = 0;
  late String trigger;
  late String content;
  bool isFavorite = false;
  int usageCount = 0;
  DateTime? lastUsed;
  DateTime createdAt = DateTime.now();
  bool isAiMacro = false;
  String? aiInstruction;
  String category = 'General';

  MacroLocalModel();

  factory MacroLocalModel.fromEntity(Map<String, dynamic> json) {
    final model = MacroLocalModel();
    model.id =
        json['id'] is int ? json['id'] : int.parse(json['id'].toString());
    model.trigger = json['trigger'] ?? '';
    model.content = json['content'] ?? '';
    model.isFavorite = json['is_favorite'] == true || json['is_favorite'] == 1;
    model.usageCount = json['usage_count'] ?? 0;
    model.lastUsed =
        json['last_used'] != null ? DateTime.parse(json['last_used']) : null;
    model.createdAt = json['created_at'] != null
        ? DateTime.parse(json['created_at'])
        : DateTime.now();
    model.isAiMacro = json['is_ai_macro'] == true || json['is_ai_macro'] == 1;
    model.aiInstruction = json['ai_instruction'];
    model.category = json['category'] ?? 'General';
    return model;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'trigger': trigger,
      'content': content,
      'is_favorite': isFavorite,
      'usage_count': usageCount,
      if (lastUsed != null) 'last_used': lastUsed!.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'is_ai_macro': isAiMacro,
      if (aiInstruction != null) 'ai_instruction': aiInstruction,
      'category': category,
    };
  }
}
