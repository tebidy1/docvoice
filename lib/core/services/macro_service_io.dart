import 'package:shared_preferences/shared_preferences.dart';
import '../entities/macro.dart';
import 'dart:convert';
import '../ai/ai_prompt_constants.dart';

class MacroService {
  static final MacroService _instance = MacroService._internal();
  factory MacroService() => _instance;
  MacroService._internal();

  static const _macrosKey = 'local_macros';
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;
    await _seedDefaultMacrosIfNeeded();
    _isInitialized = true;
  }

  Future<List<Macro>> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_macrosKey);
    if (jsonString == null) return [];
    final decoded = jsonDecode(jsonString) as List;
    return decoded.map((json) => Macro.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<void> _saveToPrefs(List<Macro> macros) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = macros.map((m) => m.toJson()).toList();
    await prefs.setString(_macrosKey, jsonEncode(jsonList));
  }

  Future<void> _seedDefaultMacrosIfNeeded() async {
    try {
      final macros = await _loadFromPrefs();
      final count = macros.length;
      final hasMarkdown = macros.any((m) => m.content.contains('**'));

      if (count != 6 || hasMarkdown) {
        await _saveToPrefs([]);
        await seedDefaultMacros();
      }
    } catch (e) {
      print("MacroService: Error checking/seeding macros: $e");
    }
  }

  Future<void> seedDefaultMacros() async {
    try {
      final macros = <Macro>[];

      void addSeed(String trigger, String content, {String category = 'General'}) {
        final m = Macro()
          ..trigger = trigger
          ..content = content
          ..category = category
          ..isAiMacro = false;
        m.id = macros.length + 1;
        macros.add(m);
      }

      addSeed("📝 Classic SOAP", AIPromptConstants.templateClassicSoap, category: "General");
      addSeed("🚨 ER SOAP", AIPromptConstants.templateErSoap, category: "Emergency");
      addSeed("📞 SBAR Consult", AIPromptConstants.templateSbar, category: "Referral");
      addSeed("📄 ER Discharge", AIPromptConstants.templateDischarge, category: "Emergency");
      addSeed("🤒 Sick Leave", AIPromptConstants.templateSickLeave, category: "Admin");
      addSeed("✨ Free Note", AIPromptConstants.templateFreeNote, category: "General");

      await _saveToPrefs(macros);
      print("MacroService: Seeded ${macros.length} default macros");
    } catch (e) {
      print("MacroService: Error seeding default macros: $e");
      rethrow;
    }
  }

  Future<void> addMacro(String trigger, String content,
      {bool isAiMacro = false, String? aiInstruction, String category = 'General'}) async {
    await init();
    final macros = await _loadFromPrefs();
    final macro = Macro()
      ..trigger = trigger
      ..content = content
      ..isAiMacro = isAiMacro
      ..aiInstruction = aiInstruction
      ..category = category;
    macro.id = macros.isEmpty ? 1 : (macros.map((m) => m.id).reduce((a, b) => a > b ? a : b) + 1);
    macros.add(macro);
    await _saveToPrefs(macros);
  }

  Future<void> deleteMacro(int id) async {
    await init();
    final macros = await _loadFromPrefs();
    macros.removeWhere((m) => m.id == id);
    await _saveToPrefs(macros);
  }

  Future<void> updateMacro(int id, String trigger, String content,
      {bool? isAiMacro, String? aiInstruction, String? category}) async {
    await init();
    final macros = await _loadFromPrefs();
    final index = macros.indexWhere((m) => m.id == id);
    if (index != -1) {
      macros[index].trigger = trigger;
      macros[index].content = content;
      if (isAiMacro != null) macros[index].isAiMacro = isAiMacro;
      if (aiInstruction != null) macros[index].aiInstruction = aiInstruction;
      if (category != null) macros[index].category = category;
      await _saveToPrefs(macros);
    }
  }

  Future<void> toggleFavorite(int id) async {
    await init();
    final macros = await _loadFromPrefs();
    final index = macros.indexWhere((m) => m.id == id);
    if (index != -1) {
      macros[index].isFavorite = !macros[index].isFavorite;
      await _saveToPrefs(macros);
    }
  }

  Future<List<Macro>> getAllMacros() async {
    await init();
    return _loadFromPrefs();
  }

  Future<List<Macro>> getMacros() => getAllMacros();

  Future<List<Macro>> getMacrosByCategory(String category) async {
    final macros = await getAllMacros();
    return macros.where((m) => m.category == category).toList()
      ..sort((a, b) => a.trigger.compareTo(b.trigger));
  }

  Future<List<Macro>> getMostUsed({int limit = 10}) async {
    final macros = await getAllMacros();
    macros.sort((a, b) => b.usageCount.compareTo(a.usageCount));
    return macros.take(limit).toList();
  }

  Future<List<String>> getCategories() async {
    final macros = await getAllMacros();
    final categories = macros.map((m) => m.category).toSet().toList();
    categories.sort();
    return categories;
  }

  Future<List<Macro>> getFavorites() async {
    final macros = await getAllMacros();
    return macros.where((m) => m.isFavorite).toList()
      ..sort((a, b) => a.trigger.compareTo(b.trigger));
  }

  Future<String?> findExpansion(String text) async {
    final macros = await getAllMacros();
    macros.sort((a, b) => b.trigger.length.compareTo(a.trigger.length));
    final normalizedText = text.toLowerCase();
    for (var macro in macros) {
      if (normalizedText.contains(macro.trigger.toLowerCase())) {
        return macro.content;
      }
    }
    return null;
  }

  Future<String> getMacrosAsJson() async {
    try {
      final macros = await getAllMacros();
      final jsonList = macros.map((m) => {
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
