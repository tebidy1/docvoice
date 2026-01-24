// import 'package:isar/isar.dart';  // Disabled for web compatibility

// part 'macro.g.dart';  // Disabled for web compatibility

// @collection  // Disabled for web compatibility
class Macro {
  // Id id = Isar.autoIncrement;  // Disabled for web compatibility
  int id = 0; // Simple ID for web compatibility

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
