import '../../domain/entities/macro_entity.dart';

class MacroDto {
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

  const MacroDto({
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

  factory MacroDto.fromJson(Map<String, dynamic> json) {
    return MacroDto(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      trigger: json['trigger'] ?? '',
      content: json['content'] ?? '',
      isFavorite: json['is_favorite'] == true || json['is_favorite'] == 1,
      usageCount: json['usage_count'] ?? 0,
      lastUsed:
          json['last_used'] != null ? DateTime.parse(json['last_used']) : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      isAiMacro: json['is_ai_macro'] == true || json['is_ai_macro'] == 1,
      aiInstruction: json['ai_instruction'],
      category: json['category'] ?? 'General',
    );
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

  MacroEntity toEntity() {
    return MacroEntity(
      id: id,
      trigger: trigger,
      content: content,
      isFavorite: isFavorite,
      usageCount: usageCount,
      lastUsed: lastUsed,
      createdAt: createdAt,
      isAiMacro: isAiMacro,
      aiInstruction: aiInstruction,
      category: category,
    );
  }

  static MacroDto fromEntity(MacroEntity entity) {
    return MacroDto(
      id: entity.id,
      trigger: entity.trigger,
      content: entity.content,
      isFavorite: entity.isFavorite,
      usageCount: entity.usageCount,
      lastUsed: entity.lastUsed,
      createdAt: entity.createdAt,
      isAiMacro: entity.isAiMacro,
      aiInstruction: entity.aiInstruction,
      category: entity.category,
    );
  }
}
