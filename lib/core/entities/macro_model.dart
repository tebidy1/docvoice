class MacroModel {
  dynamic id;
  String trigger;
  String content;
  bool isFavorite;
  String category;

  int? usageCount;
  DateTime? lastUsed;
  bool isAiMacro;
  String? aiInstruction;
  DateTime? createdAt;

  MacroModel({
    required this.id,
    required this.trigger,
    required this.content,
    this.isFavorite = false,
    this.category = 'General',
    this.usageCount,
    this.lastUsed,
    this.isAiMacro = false,
    this.aiInstruction,
    this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'trigger': trigger,
        'content': content,
        'isFavorite': isFavorite,
        'category': category,
        if (usageCount != null) 'usage_count': usageCount,
        if (lastUsed != null) 'last_used': lastUsed?.toIso8601String(),
        'is_ai_macro': isAiMacro,
        if (aiInstruction != null) 'ai_instruction': aiInstruction,
        if (createdAt != null) 'created_at': createdAt?.toIso8601String(),
      };

  Map<String, dynamic> toApiJson() => {
        'trigger': trigger,
        'content': content,
        'category': category,
        'is_ai_macro': isAiMacro,
        if (aiInstruction != null) 'ai_instruction': aiInstruction,
      };

  factory MacroModel.fromJson(Map<String, dynamic> json) {
    return MacroModel(
      id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      trigger: json['trigger'] ?? "",
      content: json['content'] ?? "",
      isFavorite: json['isFavorite'] ?? json['is_favorite'] ?? false,
      category: json['category'] ?? "General",
      usageCount: json['usage_count'],
      lastUsed:
          json['last_used'] != null ? DateTime.parse(json['last_used']) : null,
      isAiMacro: json['is_ai_macro'] ?? false,
      aiInstruction: json['ai_instruction'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }

  factory MacroModel.fromApi(Map<String, dynamic> json) {
    return MacroModel(
      id: json['id'],
      trigger: json['trigger'] ?? "",
      content: json['content'] ?? "",
      isFavorite: json['is_favorite'] ?? false,
      category: json['category'] ?? "General",
      usageCount: json['usage_count'] ?? 0,
      lastUsed:
          json['last_used'] != null ? DateTime.parse(json['last_used']) : null,
      isAiMacro: json['is_ai_macro'] ?? false,
      aiInstruction: json['ai_instruction'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }
}
