class MacroEntity {
  final int id;
  final String trigger;
  final String content;
  final bool isFavorite;
  final int usageCount;
  final DateTime? lastUsed;
  final DateTime createdAt;
  final bool isAiMacro;
  final String? aiInstruction;
  final String category;

  const MacroEntity({
    required this.id,
    required this.trigger,
    required this.content,
    this.isFavorite = false,
    this.usageCount = 0,
    this.lastUsed,
    required this.createdAt,
    this.isAiMacro = false,
    this.aiInstruction,
    this.category = 'General',
  });

  MacroEntity copyWith({
    int? id,
    String? trigger,
    String? content,
    bool? isFavorite,
    int? usageCount,
    DateTime? lastUsed,
    DateTime? createdAt,
    bool? isAiMacro,
    String? aiInstruction,
    String? category,
  }) {
    return MacroEntity(
      id: id ?? this.id,
      trigger: trigger ?? this.trigger,
      content: content ?? this.content,
      isFavorite: isFavorite ?? this.isFavorite,
      usageCount: usageCount ?? this.usageCount,
      lastUsed: lastUsed ?? this.lastUsed,
      createdAt: createdAt ?? this.createdAt,
      isAiMacro: isAiMacro ?? this.isAiMacro,
      aiInstruction: aiInstruction ?? this.aiInstruction,
      category: category ?? this.category,
    );
  }
}
