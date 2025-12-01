import 'package:isar/isar.dart';

part 'macro.g.dart';

@collection
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
}
