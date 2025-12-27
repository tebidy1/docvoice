import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class MacroModel {
  String id;
  String trigger;
  String content;

  MacroModel({required this.id, required this.trigger, required this.content});

  Map<String, dynamic> toJson() => {
    'id': id,
    'trigger': trigger,
    'content': content,
  };

  factory MacroModel.fromJson(Map<String, dynamic> json) {
    return MacroModel(
      id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      trigger: json['trigger'] ?? "",
      content: json['content'] ?? "",
    );
  }
}

class MacroService {
  static const String _storageKey = 'user_macros';

  Future<List<MacroModel>> getMacros() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(_storageKey);
    if (data == null) {
      // Seed Defaults
      final defaults = _defaultMacros();
      await saveMacros(defaults);
      return defaults;
    }
    
    try {
      final List<dynamic> decoded = jsonDecode(data);
      return decoded.map((e) => MacroModel.fromJson(e)).toList();
    } catch (e) {
      return _defaultMacros();
    }
  }

  Future<void> saveMacros(List<MacroModel> macros) async {
    final prefs = await SharedPreferences.getInstance();
    final String data = jsonEncode(macros.map((e) => e.toJson()).toList());
    await prefs.setString(_storageKey, data);
  }

  Future<void> addMacro(MacroModel macro) async {
    final macros = await getMacros();
    macros.add(macro);
    await saveMacros(macros);
  }

  Future<void> updateMacro(MacroModel updated) async {
    final macros = await getMacros();
    final index = macros.indexWhere((m) => m.id == updated.id);
    if (index != -1) {
      macros[index] = updated;
      await saveMacros(macros);
    }
  }

  Future<void> deleteMacro(String id) async {
    final macros = await getMacros();
    macros.removeWhere((m) => m.id == id);
    await saveMacros(macros);
  }

  List<MacroModel> _defaultMacros() {
    return [
       MacroModel(id: '1', trigger: '⚡ SOAP', content: 'Subjective:\n\nObjective:\n\nAssessment:\n\nPlan:\n'),
       MacroModel(id: '2', trigger: '🫀 Cardio', content: 'Patient denies chest pain, palpitations, or shortness of breath.'),
       MacroModel(id: '3', trigger: '📝 Referral', content: 'Referral to [Specialty] for evaluation of [Condition].'),
       MacroModel(id: '4', trigger: '💊 RX', content: 'Prescription: [Medication] [Dose] [Freq]'),
       MacroModel(id: '5', trigger: '🧬 Lab', content: 'Ordered: CBC, CMP, Lipid Panel, TSH.'),
    ];
  }
}
