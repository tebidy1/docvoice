import 'package:isar/isar.dart';

part 'macro_io.g.dart';

@Collection()
class Macro {
  Id id = Isar.autoIncrement;

  @Index(type: IndexType.value)
  late String trigger; // The phrase to say, e.g., "Normal Cardio"

  late String content; // The text to insert

  bool isFavorite = false;

  int usageCount = 0;

  DateTime? lastUsed;

  DateTime createdAt = DateTime.now();

  bool isAiMacro = false;

  String? aiInstruction; // Custom instruction for Gemini

  String category = 'General'; // Category: Cardiology, Pediatrics, etc.

  // Default constructor
  Macro();

  // ============================================
  // JSON Serialization
  // ============================================

  /// Convert from JSON (API response)
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

  /// Convert to JSON (for API requests)
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
