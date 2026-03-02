import 'package:isar/isar.dart';
import '../models/macro.dart';
import 'database_service.dart';
import 'dart:async';
import 'dart:convert';
import '../core/ai/ai_prompt_constants.dart';

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
      
      final firstMacro = await isar.macros.where().findFirst();
      final hasMarkdown = firstMacro?.content.contains('**') ?? false;

      // Force update: wipe old macros and seed the new CBAHI ones
      if (count != 6 || hasMarkdown) {
        print("MacroService: DB state needs update (count: $count, hasMarkdown: $hasMarkdown). Clearing and re-seeding...");
        await isar.writeTxn(() async {
          await isar.macros.clear();
        });
        await seedDefaultMacros();
      } else {
        print("MacroService: Database already contains $count macros (CBAHI templates confirmed).");
      }
    } catch (e) {
      print("MacroService: Error checking/seeding macros: $e");
    }
  }

  /// Force seed default macros (can be called manually to reset)
  Future<void> seedDefaultMacros() async {
    try {
      print("MacroService: Seeding default macros...");
      
      // 1. Classic Clinic SOAP Note
      await addMacro(
        "📝 Classic SOAP", 
        AIPromptConstants.templateClassicSoap, 
        category: "General"
      );
      print("MacroService: ✓ Added 'Classic SOAP'");

      // 2. ER SOAP Note
      await addMacro(
        "🚨 ER SOAP", 
        AIPromptConstants.templateErSoap, 
        category: "Emergency"
      );
      print("MacroService: ✓ Added 'ER SOAP'");

      // 3. SBAR Consultation
      await addMacro(
        "📞 SBAR Consult", 
        AIPromptConstants.templateSbar, 
        category: "Referral"
      );
      print("MacroService: ✓ Added 'SBAR Consult'");

      // 4. ER Discharge Summary
      await addMacro(
        "📄 ER Discharge", 
        AIPromptConstants.templateDischarge, 
        category: "Emergency"
      );
      print("MacroService: ✓ Added 'ER Discharge'");

      // 5. Sick Leave
      await addMacro(
        "🤒 Sick Leave", 
        AIPromptConstants.templateSickLeave, 
        category: "Admin"
      );
      print("MacroService: ✓ Added 'Sick Leave'");

      // 6. Free Note
      await addMacro(
        "✨ Free Note", 
        AIPromptConstants.templateFreeNote, 
        category: "General"
      );
      print("MacroService: ✓ Added 'Free Note'");
      
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

  Future<void> deleteMacro(int id) async {
    await init();
    final isar = await _dbService.isar;
    await isar.writeTxn(() async {
      await isar.macros.delete(id);
    });
  }

  Future<void> updateMacro(int id, String trigger, String content, {bool? isAiMacro, String? aiInstruction, String? category}) async {
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

  Future<void> toggleFavorite(int id) async {
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
  /// Returns macros as JSON string (for ConnectivityServer)
  Future<String> getMacrosAsJson() async {
    try {
      final macros = await getAllMacros();
      final List<Map<String, dynamic>> jsonList = macros.map((m) => {
        'id': m.id,
        'trigger': m.trigger,
        'content': m.content,
        'category': m.category,
      }).toList();
      return jsonEncode(jsonList);
    } catch (e) {
      print('Error getting macros as JSON: $e');
      return "[]";
    }
  }
}
