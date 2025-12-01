import 'package:isar/isar.dart';
import '../models/macro.dart';
import 'database_service.dart';
import 'dart:async';

class MacroService {
  // Singleton pattern
  static final MacroService _instance = MacroService._internal();
  factory MacroService() => _instance;
  MacroService._internal();
  
  final DatabaseService _dbService = DatabaseService();
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) {
      print("MacroService: Already initialized");
      return;
    }
    
    print("MacroService: Starting initialization...");
    await _dbService.init();
    _isInitialized = true;
    print("MacroService: Database ready");
    
    // Check and seed default macros
    await _seedDefaultMacrosIfNeeded();
  }

  /// Seeds default macros if the database is empty
  Future<void> _seedDefaultMacrosIfNeeded() async {
    try {
      final isar = await _dbService.isar;
      final count = await isar.macros.count();
      print("MacroService: Current macro count: $count");
      
      if (count == 0) {
        print("MacroService: Database is empty, adding default macros...");
        await seedDefaultMacros();
      } else {
        print("MacroService: Database already contains $count macros");
        // List existing macros for debugging
        final macros = await getAllMacros();
        for (var macro in macros) {
          print("MacroService: Existing macro - '${macro.trigger}': ${macro.content.substring(0, 30)}...");
        }
      }
    } catch (e) {
      print("MacroService: Error checking/seeding macros: $e");
    }
  }

  /// Force seed default macros (can be called manually to reset)
  Future<void> seedDefaultMacros() async {
    try {
      print("MacroService: Seeding default macros...");
      
      await addMacro("Normal Cardio", "Regular rate and rhythm. No murmurs, rubs, or gallops. S1 and S2 normal.", category: "Cardiology");
      print("MacroService: ✓ Added 'Normal Cardio'");
      
      await addMacro("Normal Lung", "Lungs clear to auscultation bilaterally. No wheezes, rales, or rhonchi.", category: "Pulmonology");
      print("MacroService: ✓ Added 'Normal Lung'");
      
      await addMacro("Normal Abdomen", "Soft, non-tender, non-distended. Bowel sounds present. No organomegaly.", category: "Gastroenterology");
      print("MacroService: ✓ Added 'Normal Abdomen'");
      
      await addMacro("Insert Normal BP", "Blood Pressure: 120/80 mmHg, Heart Rate: 72 bpm, Regular rhythm, SPO2: 98% on room air.", category: "General");
      print("MacroService: ✓ Added 'Insert Normal BP'");
      
      await addMacro("Normal Neuro", "Alert and oriented x3. Cranial nerves II-XII intact. Motor strength 5/5 in all extremities. Sensory intact to light touch.", category: "Neurology");
      print("MacroService: ✓ Added 'Normal Neuro'");
      
      await addMacro("Plan Diabetes", "1. Continue Metformin 500mg BID\n2. Check HbA1c in 3 months\n3. Self-monitoring blood glucose\n4. Diet and exercise counseling", category: "General");
      print("MacroService: ✓ Added 'Plan Diabetes'");
      
      final isar = await _dbService.isar;
      final finalCount = await isar.macros.count();
      print("MacroService: ✅ Successfully seeded $finalCount default macros");
    } catch (e) {
      print("MacroService: ❌ Error seeding default macros: $e");
      rethrow;
    }
  }

  Future<void> addMacro(String trigger, String content, {bool isAiMacro = false, String? aiInstruction, String category = 'General'}) async {
    await init(); // Ensure initialized
    try {
      final isar = await _dbService.isar;
      final macro = Macro()
        ..trigger = trigger
        ..content = content
        ..isAiMacro = isAiMacro
        ..aiInstruction = aiInstruction
        ..category = category;

      await isar.writeTxn(() async {
        await isar.macros.put(macro);
      });
      
      print("MacroService: Added macro '$trigger' in category '$category'");
    } catch (e) {
      print("MacroService: Error adding macro '$trigger': $e");
      rethrow;
    }
  }

  Future<void> deleteMacro(Id id) async {
    await init();
    final isar = await _dbService.isar;
    await isar.writeTxn(() async {
      await isar.macros.delete(id);
    });
  }

  Future<void> updateMacro(Id id, String trigger, String content, {bool? isAiMacro, String? aiInstruction, String? category}) async {
    await init();
    try {
      final isar = await _dbService.isar;
      await isar.writeTxn(() async {
        final macro = await isar.macros.get(id);
        if (macro != null) {
          macro.trigger = trigger;
          macro.content = content;
          if (isAiMacro != null) macro.isAiMacro = isAiMacro;
          if (aiInstruction != null) macro.aiInstruction = aiInstruction;
          if (category != null) macro.category = category;
          await isar.macros.put(macro);
        }
      });
      
      print("MacroService: Updated macro '$trigger'");
    } catch (e) {
      print("MacroService: Error updating macro: $e");
      rethrow;
    }
  }

  Future<void> toggleFavorite(Id id) async {
    await init();
    final isar = await _dbService.isar;
    await isar.writeTxn(() async {
      final macro = await isar.macros.get(id);
      if (macro != null) {
        macro.isFavorite = !macro.isFavorite;
        await isar.macros.put(macro);
      }
    });
  }

  Future<List<Macro>> getAllMacros() async {
    await init();
    final isar = await _dbService.isar;
    return await isar.macros.where().findAll();
  }

  /// Get macros by category
  Future<List<Macro>> getMacrosByCategory(String category) async {
    await init();
    final isar = await _dbService.isar;
    return await isar.macros
        .filter()
        .categoryEqualTo(category)
        .sortByTrigger()
        .findAll();
  }

  /// Get most used macros
  Future<List<Macro>> getMostUsed({int limit = 10}) async {
    await init();
    final isar = await _dbService.isar;
    return await isar.macros
        .where()
        .sortByUsageCountDesc()
        .limit(limit)
        .findAll();
  }

  /// Get all unique categories
  Future<List<String>> getCategories() async {
    await init();
    final isar = await _dbService.isar;
    final macros = await isar.macros.where().findAll();
    final categories = macros.map((m) => m.category).toSet().toList();
    categories.sort();
    return categories;
  }

  /// Get favorite macros
  Future<List<Macro>> getFavorites() async {
    await init();
    final isar = await _dbService.isar;
    return await isar.macros
        .filter()
        .isFavoriteEqualTo(true)
        .sortByTrigger()
        .findAll();
  }

  /// Checks if the [text] contains any macro trigger.
  /// Returns the content of the matched macro, or null if none found.
  Future<String?> findExpansion(String text) async {
    final macros = await getAllMacros();
    
    // Sort by length descending to match longest phrases first
    // e.g. match "Normal Cardio Exam" before "Normal Cardio"
    macros.sort((a, b) => b.trigger.length.compareTo(a.trigger.length));
    
    final normalizedText = text.toLowerCase();
    
    for (var macro in macros) {
      if (normalizedText.contains(macro.trigger.toLowerCase())) {
        return macro.content;
      }
    }
    
    return null;
  }
}
