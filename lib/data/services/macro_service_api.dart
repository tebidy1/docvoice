import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soutnote/core/entities/macro.dart';
import 'package:soutnote/core/network/api_client.dart';
import 'package:soutnote/core/ai/ai_prompt_constants.dart';

class MacroService {
  static final MacroService _instance = MacroService._internal();
  factory MacroService() => _instance;
  MacroService._internal();

  static const String _storageKey = 'user_macros';
  static const String _lastSyncKey = 'macros_last_sync';
  static const String _migratedKey = 'macros_migrated_to_cloud';

  final ApiClient _ApiClient = ApiClient();
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) {
      return;
    }
    await _ApiClient.init();
    _isInitialized = true;
  }

  Future<List<Macro>> getMacros() async {
    try {
      await _ApiClient.init();
      final response = await _ApiClient.get('/macros');

      if (response['status'] == true && response['payload'] != null) {
        final payload = response['payload'];
        final List<dynamic> data = payload['data'] is List
            ? payload['data']
            : (payload is List ? payload : []);

        final macros = data.map((json) => _mapToMacro(json)).toList();

        final legacyTriggers = [
          '📝 SOAP Note',
          '🤒 Sick Leave',
          '📄 Medical Report',
          '🏥 Referral',
          '☢️ Radiology Req',
          '🩸 Diabetic Follow-up',
          '🧠 Neuro Exam',
          '🦴 Joint Exam'
        ];

        final hasLegacy = macros
            .any((m) => legacyTriggers.contains(m.trigger) && !m.isAiMacro);

        if (hasLegacy) {
          debugPrint(
              "MacroService: Detected legacy macros in Cloud. Auto-migrating backend...");

          for (var m in macros) {
            if (legacyTriggers.contains(m.trigger) && !m.isAiMacro) {
              if (m.id != 0) {
                try {
                  await _ApiClient.delete('/macros/${m.id}');
                } catch (e) {
                  debugPrint("Failed to delete legacy macro ${m.id}: $e");
                }
              }
            }
          }

          await seedDefaultMacrosToCloud();
          return await getMacros();
        }

        final defaults = _defaultMacros();
        for (final def in defaults) {
          if (!macros.any((m) =>
              m.trigger.trim().toUpperCase() ==
              def.trigger.trim().toUpperCase())) {
            debugPrint(
                "MacroService: '${def.trigger}' missing in Cloud. Auto-adding...");
            try {
              await addMacro(def.trigger, def.content,
                  isAiMacro: def.isAiMacro,
                  aiInstruction: def.aiInstruction,
                  category: def.category);
              macros.add(def);
            } catch (e) {
              debugPrint("Failed to add ${def.trigger} to Cloud: $e");
            }
          }
        }
        await _cacheLocally(macros);
        await _updateLastSync();

        return macros;
      }
    } catch (e) {
      debugPrint("API failed, using cache: $e");
    }

    return await _getFromCache();
  }

  Future<void> addMacro(
    String trigger,
    String content, {
    bool isAiMacro = false,
    String? aiInstruction,
    String category = 'General',
  }) async {
    try {
      await _ApiClient.init();
      final response = await _ApiClient.post('/macros', body: {
        'trigger': trigger,
        'content': content,
        'is_ai_macro': isAiMacro,
        if (aiInstruction != null) 'ai_instruction': aiInstruction,
        'category': category,
      });

      if (response['status'] == true) {
        await getMacros();
      }
    } catch (e) {
      debugPrint("Failed to add macro to API: $e");
      final macros = await _getFromCache();
      final macro = Macro()
        ..trigger = trigger
        ..content = content
        ..isAiMacro = isAiMacro
        ..aiInstruction = aiInstruction
        ..category = category;
      macros.add(macro);
      await _cacheLocally(macros);
    }
  }

  Future<void> updateMacro(
    int id,
    String trigger,
    String content, {
    bool? isAiMacro,
    String? aiInstruction,
    String? category,
  }) async {
    try {
      await _ApiClient.init();
      final body = <String, dynamic>{
        'trigger': trigger,
        'content': content,
      };

      if (isAiMacro != null) body['is_ai_macro'] = isAiMacro;
      if (aiInstruction != null) body['ai_instruction'] = aiInstruction;
      if (category != null) body['category'] = category;

      final response = await _ApiClient.put('/macros/$id', body: body);

      if (response['status'] == true) {
        await getMacros();
      }
    } catch (e) {
      debugPrint("Failed to update macro: $e");
      final macros = await _getFromCache();
      final index = macros.indexWhere((m) => m.id == id);
      if (index != -1) {
        macros[index].trigger = trigger;
        macros[index].content = content;
        if (isAiMacro != null) macros[index].isAiMacro = isAiMacro;
        if (aiInstruction != null) macros[index].aiInstruction = aiInstruction;
        if (category != null) macros[index].category = category;
        await _cacheLocally(macros);
      }
    }
  }

  Future<void> toggleFavorite(int id) async {
    try {
      await _ApiClient.init();
      try {
        await _ApiClient.patch('/macros/$id/toggle-favorite');
      } catch (_) {}
      await getMacros();
    } catch (e) {
      debugPrint("Toggle favorite failed: $e");
    }
  }

  Future<void> deleteMacro(int id) async {
    try {
      await _ApiClient.init();
      await _ApiClient.delete('/macros/$id');
      await getMacros();
    } catch (e) {
      debugPrint("Failed to delete macro: $e");
      final macros = await _getFromCache();
      macros.removeWhere((m) => m.id == id);
      await _cacheLocally(macros);
    }
  }

  Future<void> resetToDefaults() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
    await prefs.remove(_migratedKey);
    await seedDefaultMacrosToCloud();
  }

  Future<void> seedDefaultMacrosToCloud() async {
    try {
      final defaults = _defaultMacros();

      for (final macro in defaults) {
        try {
          await addMacro(macro.trigger, macro.content,
              isAiMacro: macro.isAiMacro,
              aiInstruction: macro.aiInstruction,
              category: macro.category);
          debugPrint("Seeded macro: ${macro.trigger}");
        } catch (e) {
          debugPrint("Failed to seed ${macro.trigger}: $e");
        }
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_migratedKey, true);
    } catch (e) {
      debugPrint("Failed to seed defaults: $e");
    }
  }

  Future<void> migrateLocalToCloud() async {
    final prefs = await SharedPreferences.getInstance();
    final alreadyMigrated = prefs.getBool(_migratedKey) ?? false;

    if (!alreadyMigrated) {
      debugPrint("Migrating local macros to cloud...");
      final localMacros = await _getFromCache();

      for (final macro in localMacros) {
        try {
          await addMacro(macro.trigger, macro.content,
              isAiMacro: macro.isAiMacro,
              aiInstruction: macro.aiInstruction,
              category: macro.category);
        } catch (e) {
          debugPrint("Migration failed for ${macro.trigger}: $e");
        }
      }

      await prefs.setBool(_migratedKey, true);
      debugPrint("Migration complete");
    }
  }

  Future<List<Macro>> getAllMacros() => getMacros();

  Future<List<Macro>> getMacrosByCategory(String category) async {
    final macros = await getMacros();
    return macros.where((m) => m.category == category).toList();
  }

  Future<List<Macro>> getMostUsed({int limit = 10}) async {
    final macros = await getMacros();
    macros.sort((a, b) => b.usageCount.compareTo(a.usageCount));
    return macros.take(limit).toList();
  }

  Future<List<String>> getCategories() async {
    final macros = await getMacros();
    final categories = macros.map((m) => m.category).toSet().toList();
    categories.sort();
    return categories;
  }

  Future<List<Macro>> getFavorites() async {
    final macros = await getMacros();
    return macros.where((m) => m.isFavorite).toList();
  }

  Future<String?> findExpansion(String text) async {
    try {
      final macros = await getMacros();

      macros.sort((a, b) => b.trigger.length.compareTo(a.trigger.length));

      final normalizedText = text.toLowerCase();

      for (var macro in macros) {
        if (normalizedText.contains(macro.trigger.toLowerCase())) {
          await _incrementUsage(macro.id);
          return macro.content;
        }
      }

      return null;
    } catch (e) {
      debugPrint('Error finding expansion: $e');
      return null;
    }
  }

  Future<void> _incrementUsage(int id) async {
    try {
      await _ApiClient.patch('/macros/$id/increment-usage');
    } catch (e) {
      debugPrint('Error incrementing usage: $e');
    }
  }

  Future<String> getMacrosAsJson() async {
    try {
      final macros = await getMacros();
      final List<Map<String, dynamic>> jsonList = macros
          .map((m) => {
                'id': m.id,
                'trigger': m.trigger,
                'content': m.content,
                'category': m.category,
              })
          .toList();
      return jsonEncode(jsonList);
    } catch (e) {
      return "[]";
    }
  }

  Future<void> saveMacros(List<Macro> macros) async {
    await _cacheLocally(macros);
  }

  Future<List<Macro>> _getFromCache() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(_storageKey);

    if (data == null) {
      final defaults = _defaultMacros();
      await _cacheLocally(defaults);
      return defaults;
    }

    try {
      final List<dynamic> decoded = jsonDecode(data);
      final macros = decoded.map((e) => Macro.fromJson(e)).toList();

      if (macros.any((m) => m.trigger == '📝 SOAP Note' && !m.isAiMacro)) {
        debugPrint(
            "MacroService: Detected legacy macros in cache. Auto-upgrading to AI Brain defaults.");
        final defaults = _defaultMacros();
        await _cacheLocally(defaults);
        return defaults;
      }

      final defaults = _defaultMacros();
      for (final def in defaults) {
        if (!macros.any((m) =>
            m.trigger.trim().toUpperCase() ==
            def.trigger.trim().toUpperCase())) {
          debugPrint(
              "MacroService: '${def.trigger}' missing in cache. Auto-upgrading...");
          macros.add(def);
        }
      }
      await _cacheLocally(macros);

      return macros;
    } catch (e) {
      return _defaultMacros();
    }
  }

  Future<void> _cacheLocally(List<Macro> macros) async {
    final prefs = await SharedPreferences.getInstance();
    final String data = jsonEncode(macros.map((e) => e.toJson()).toList());
    await prefs.setString(_storageKey, data);
  }

  Future<void> _updateLastSync() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());
  }

  List<Macro> _defaultMacros() {
    return [
      Macro()
        ..trigger = '📝 Classic SOAP'
        ..category = 'General'
        ..isFavorite = true
        ..content = AIPromptConstants.templateClassicSoap
        ..isAiMacro = true,
      Macro()
        ..trigger = '🚨 ER SOAP'
        ..category = 'Emergency'
        ..isFavorite = true
        ..content = AIPromptConstants.templateErSoap
        ..isAiMacro = true,
      Macro()
        ..trigger = '📞 SBAR Consult'
        ..category = 'Referral'
        ..isFavorite = false
        ..content = AIPromptConstants.templateSbar
        ..isAiMacro = true,
      Macro()
        ..trigger = '📄 ER Discharge'
        ..category = 'Emergency'
        ..isFavorite = false
        ..content = AIPromptConstants.templateDischarge
        ..isAiMacro = true,
      Macro()
        ..trigger = '🤒 Sick Leave'
        ..category = 'Admin'
        ..isFavorite = false
        ..content = AIPromptConstants.templateSickLeave
        ..isAiMacro = true,
      Macro()
        ..trigger = '✨ Free Note'
        ..category = 'General'
        ..isFavorite = false
        ..content = AIPromptConstants.templateFreeNote
        ..isAiMacro = true,
      Macro()
        ..trigger = 'INSURANCE'
        ..category = 'Admin'
        ..isFavorite = false
        ..content =
            'Rewrite the note to emphasize medical necessity, making it suitable for insurance approval. Ensure justification for any tests, procedures, and medications is clearly documented and aligned with the reported symptoms and diagnosis.'
        ..isAiMacro = true,
    ];
  }

  Macro _mapToMacro(Map<String, dynamic> json) {
    final macro = Macro();
    macro.id =
        json['id'] is int ? json['id'] : int.parse(json['id'].toString());
    macro.trigger = json['trigger'] ?? '';
    macro.content = json['content'] ?? '';
    macro.isFavorite = json['is_favorite'] ?? false;
    macro.usageCount = json['usage_count'] ?? 0;
    macro.lastUsed =
        json['last_used'] != null ? DateTime.parse(json['last_used']) : null;
    macro.isAiMacro = json['is_ai_macro'] ?? false;
    macro.aiInstruction = json['ai_instruction'];
    macro.category = json['category'] ?? 'General';
    macro.createdAt = json['created_at'] != null
        ? DateTime.parse(json['created_at'])
        : DateTime.now();
    return macro;
  }
}
