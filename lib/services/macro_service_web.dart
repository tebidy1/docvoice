import '../models/macro.dart';
import 'dart:async';

/// Web-compatible stub for MacroService
/// On web, local database features are not supported
class MacroService {
  static final MacroService _instance = MacroService._internal();
  factory MacroService() => _instance;
  MacroService._internal();
  
  bool _isInitialized = false;
  final List<Macro> _inMemoryMacros = [];

  Future<void> init() async {
    if (_isInitialized) {
      print("MacroService (Web): Already initialized");
      return;
    }
    
    print("MacroService (Web): Starting initialization with in-memory storage...");
    _isInitialized = true;
    print("MacroService (Web): Ready (in-memory mode)");
    
    // Seed default macros in memory
    await _seedDefaultMacrosIfNeeded();
  }

  Future<void> _seedDefaultMacrosIfNeeded() async {
    if (_inMemoryMacros.isEmpty) {
      print("MacroService (Web): Seeding default macros in memory...");
      await seedDefaultMacros();
    }
  }

  Future<void> seedDefaultMacros() async {
    print("MacroService (Web): Adding default macros to memory...");
    
    await addMacro("Normal Cardio", "Regular rate and rhythm. No murmurs, rubs, or gallops. S1 and S2 normal.", category: "Cardiology");
    await addMacro("Normal Lung", "Lungs clear to auscultation bilaterally. No wheezes, rales, or rhonchi.", category: "Pulmonology");
    await addMacro("Normal Abdomen", "Soft, non-tender, non-distended. Bowel sounds present. No organomegaly.", category: "Gastroenterology");
    await addMacro("Insert Normal BP", "Blood Pressure: 120/80 mmHg, Heart Rate: 72 bpm, Regular rhythm, SPO2: 98% on room air.", category: "General");
    await addMacro("Normal Neuro", "Alert and oriented x3. Cranial nerves II-XII intact. Motor strength 5/5 in all extremities. Sensory intact to light touch.", category: "Neurology");
    await addMacro("Plan Diabetes", "1. Continue Metformin 500mg BID\n2. Check HbA1c in 3 months\n3. Self-monitoring blood glucose\n4. Diet and exercise counseling", category: "General");
    
    print("MacroService (Web): ✅ Default macros seeded in memory (${_inMemoryMacros.length} total)");
  }

  Future<void> addMacro(String trigger, String content, {bool isAiMacro = false, String? aiInstruction, String category = 'General'}) async {
    await init();
    
    final macro = Macro()
      ..id = _inMemoryMacros.length + 1
      ..trigger = trigger
      ..content = content
      ..isAiMacro = isAiMacro
      ..aiInstruction = aiInstruction
      ..category = category;
    
    _inMemoryMacros.add(macro);
    print("MacroService (Web): Added macro '$trigger' to memory");
  }

  Future<void> deleteMacro(int id) async {
    await init();
    _inMemoryMacros.removeWhere((m) => m.id == id);
    print("MacroService (Web): Deleted macro with id $id from memory");
  }

  Future<void> updateMacro(int id, String trigger, String content, {bool? isAiMacro, String? aiInstruction, String? category}) async {
    await init();
    
    final index = _inMemoryMacros.indexWhere((m) => m.id == id);
    if (index != -1) {
      _inMemoryMacros[index].trigger = trigger;
      _inMemoryMacros[index].content = content;
      if (isAiMacro != null) _inMemoryMacros[index].isAiMacro = isAiMacro;
      if (aiInstruction != null) _inMemoryMacros[index].aiInstruction = aiInstruction;
      if (category != null) _inMemoryMacros[index].category = category;
      
      print("MacroService (Web): Updated macro '$trigger' in memory");
    }
  }

  Future<void> toggleFavorite(int id) async {
    await init();
    
    final index = _inMemoryMacros.indexWhere((m) => m.id == id);
    if (index != -1) {
      _inMemoryMacros[index].isFavorite = !_inMemoryMacros[index].isFavorite;
    }
  }

  Future<List<Macro>> getAllMacros() async {
    await init();
    return List.from(_inMemoryMacros);
  }

  Future<List<Macro>> getMacrosByCategory(String category) async {
    await init();
    return _inMemoryMacros.where((m) => m.category == category).toList()
      ..sort((a, b) => a.trigger.compareTo(b.trigger));
  }

  Future<List<Macro>> getMostUsed({int limit = 10}) async {
    await init();
    final sorted = List<Macro>.from(_inMemoryMacros)
      ..sort((a, b) => b.usageCount.compareTo(a.usageCount));
    return sorted.take(limit).toList();
  }

  Future<List<String>> getCategories() async {
    await init();
    final categories = _inMemoryMacros.map((m) => m.category).toSet().toList()
      ..sort();
    return categories;
  }

  Future<List<Macro>> getFavorites() async {
    await init();
    return _inMemoryMacros.where((m) => m.isFavorite).toList()
      ..sort((a, b) => a.trigger.compareTo(b.trigger));
  }

  Future<String?> findExpansion(String text) async {
    final macros = await getAllMacros();
    
    // Sort by length descending to match longest phrases first
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
