/// Pure Macro entity - no platform dependencies
/// This is the core business entity used across all layers
class Macro {
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

  Macro();

  factory Macro.fromJson(Map<String, dynamic> json) {
    final macro = Macro();
    macro.id =
        json['id'] is int ? json['id'] : int.parse(json['id'].toString());
    macro.trigger = json['trigger'] ?? '';
    macro.content = json['content'] ?? '';
    macro.isFavorite = json['is_favorite'] == true || json['is_favorite'] == 1;
    macro.usageCount = json['usage_count'] ?? 0;
    macro.lastUsed =
        json['last_used'] != null ? DateTime.parse(json['last_used']) : null;
    macro.createdAt = json['created_at'] != null
        ? DateTime.parse(json['created_at'])
        : DateTime.now();
    macro.isAiMacro = json['is_ai_macro'] == true || json['is_ai_macro'] == 1;
    macro.aiInstruction = json['ai_instruction'];
    macro.category = json['category'] ?? 'General';
    return macro;
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