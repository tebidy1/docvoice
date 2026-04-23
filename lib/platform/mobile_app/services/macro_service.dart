import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../data/repositories/api_service.dart';
import '../../../core/ai/ai_prompt_constants.dart';

class MacroModel {
  // ID can be String (local) or int (API) - we'll manage both
  dynamic id; // Will be String for local-only, int for API-synced
  String trigger;
  String content;
  bool isFavorite;
  String category;
  
  // API-specific fields
  int? usageCount;
  DateTime? lastUsed;
  bool isAiMacro;
  String? aiInstruction;
  DateTime? createdAt;

  MacroModel({
    required this.id, 
    required this.trigger, 
    required this.content,
    this.isFavorite = false,
    this.category = 'General',
    this.usageCount,
    this.lastUsed,
    this.isAiMacro = false,
    this.aiInstruction,
    this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'trigger': trigger,
    'content': content,
    'isFavorite': isFavorite,
    'category': category,
    if (usageCount != null) 'usage_count': usageCount,
    if (lastUsed != null) 'last_used': lastUsed?.toIso8601String(),
    'is_ai_macro': isAiMacro,
    if (aiInstruction != null) 'ai_instruction': aiInstruction,
    if (createdAt != null) 'created_at': createdAt?.toIso8601String(),
  };

  // For API POST/PUT requests
  Map<String, dynamic> toApiJson() => {
    'trigger': trigger,
    'content': content,
    'category': category,
    'is_ai_macro': isAiMacro,
    if (aiInstruction != null) 'ai_instruction': aiInstruction,
  };

  factory MacroModel.fromJson(Map<String, dynamic> json) {
    return MacroModel(
      id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      trigger: json['trigger'] ?? "",
      content: json['content'] ?? "",
      isFavorite: json['isFavorite'] ?? json['is_favorite'] ?? false,
      category: json['category'] ?? "General",
      usageCount: json['usage_count'],
      lastUsed: json['last_used'] != null ? DateTime.parse(json['last_used']) : null,
      isAiMacro: json['is_ai_macro'] ?? false,
      aiInstruction: json['ai_instruction'],
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
    );
  }
  
  // Factory for API responses
  factory MacroModel.fromApi(Map<String, dynamic> json) {
    return MacroModel(
      id: json['id'], // int from API
      trigger: json['trigger'] ?? "",
      content: json['content'] ?? "",
      isFavorite: json['is_favorite'] ?? false,
      category: json['category'] ?? "General",
      usageCount: json['usage_count'] ?? 0,
      lastUsed: json['last_used'] != null ? DateTime.parse(json['last_used']) : null,
      isAiMacro: json['is_ai_macro'] ?? false,
      aiInstruction: json['ai_instruction'],
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
    );
  }
}

class MacroService {
  static const String _storageKey = 'user_macros';
  static const String _lastSyncKey = 'macros_last_sync';
  static const String _migratedKey = 'macros_migrated_to_cloud';
  
  final ApiService _apiService = ApiService();

  /// Get all macros - API first, cache fallback
  Future<List<MacroModel>> getMacros() async {
    try {
      // Try API first
      await _apiService.init();
      final response = await _apiService.get('/macros');
      
      if (response['status'] == true && response['payload'] != null) {
        final payload = response['payload'];
        final List<dynamic> data = payload['data'] is List
            ? payload['data']
            : (payload is List ? payload : []);
        
        final macros = data.map((json) => MacroModel.fromApi(json)).toList();
        
        // --- NEW CLOUD AUTO-MIGRATION LOGIC ---
        // The backend might still have the old hardcoded legacy macros.
        // If we detect them, we need to wipe them from the user's account and re-seed the new AI ones.
        final legacyTriggers = [
          '📝 SOAP Note', '🤒 Sick Leave', '📄 Medical Report', 
          '🏥 Referral', '☢️ Radiology Req', '🩸 Diabetic Follow-up', 
          '🧠 Neuro Exam', '🦴 Joint Exam'
        ];

        final hasLegacy = macros.any((m) => legacyTriggers.contains(m.trigger) && !m.isAiMacro);
        
        if (hasLegacy) {
          debugPrint("MacroService: Detected legacy macros in Cloud. Auto-migrating backend...");
          
          for (var m in macros) {
            if (legacyTriggers.contains(m.trigger) && !m.isAiMacro) {
               if (m.id != null) {
                  try {
                    await _apiService.delete('/macros/${m.id}');
                  } catch (e) {
                    debugPrint("Failed to delete legacy macro ${m.id}: $e");
                  }
               }
            }
          }
          
          // Seed the new unified AI defaults
          await seedDefaultMacrosToCloud();
          
          // Re-fetch clean macros from the backend
          return await getMacros();
        }
        // --- END AUTO-MIGRATION LOGIC ---
        
        // Auto-add Free Note to cloud if missing for existing users
        if (!macros.any((m) => m.trigger == '✨ Free Note')) {
           debugPrint("MacroService: '✨ Free Note' missing in Cloud. Auto-adding...");
           try {
             final freeNote = _defaultMacros().firstWhere((m) => m.trigger == '✨ Free Note');
             await addMacro(freeNote);
             macros.add(freeNote);
           } catch (e) {
             debugPrint("Failed to add Free Note to Cloud: $e");
           }
        }
        // Cache for offline use
        await _cacheLocally(macros);
        await _updateLastSync();
        
        return macros;
      }
    } catch (e) {
      debugPrint("API failed, using cache: $e");
    }
    
    // Fallback to cache
    return await _getFromCache();
  }

  /// Add a new macro - saves to API and cache
  Future<void> addMacro(MacroModel macro) async {
    try {
      await _apiService.init();
      final response = await _apiService.post('/macros', body: macro.toApiJson());
      
      if (response['status'] == true) {
        // Refresh from API to get server-assigned ID
        await getMacros();
      }
    } catch (e) {
      debugPrint("Failed to add macro to API: $e");
      // Fallback: save locally only
      final macros = await _getFromCache();
      macros.add(macro);
      await _cacheLocally(macros);
    }
  }

  /// Update existing macro
  Future<void> updateMacro(MacroModel updated) async {
    try {
      if (updated.id is int) { // API ID
        await _apiService.init();
        final response = await _apiService.put('/macros/${updated.id}', body: updated.toApiJson());
        
        if (response['status'] == true) {
          await getMacros(); // Refresh
        }
      } else {
        // Local-only macro - update cache
        final macros = await _getFromCache();
        final index = macros.indexWhere((m) => m.id == updated.id);
        if (index != -1) {
          macros[index] = updated;
          await _cacheLocally(macros);
        }
      }
    } catch (e) {
      debugPrint("Failed to update macro: $e");
      // Fallback to local update
      final macros = await _getFromCache();
      final index = macros.indexWhere((m) => m.id == updated.id);
      if (index != -1) {
        macros[index] = updated;
        await _cacheLocally(macros);
      }
    }
  }

  /// Toggle Favorite Status
  Future<void> toggleFavorite(dynamic id) async {
    try {
       if (id is int) { // API ID
         await _apiService.init();
         // Attempt to use dedicated endpoint if available, otherwise rely on local update + PUT
         // But for now, we will optimistically update local and try PATCH
         try {
            await _apiService.patch('/macros/$id/toggle-favorite');
         } catch (_) {
            // Fallback if endpoint missing? Assume updateMacro helps.
         }
         await getMacros();
       } else {
         // Local
         final macros = await _getFromCache();
         final index = macros.indexWhere((m) => m.id == id);
         if (index != -1) {
           macros[index].isFavorite = !macros[index].isFavorite;
           await _cacheLocally(macros);
         }
       }
    } catch (e) {
      debugPrint("Toggle favorite failed: $e");
    }
  }

  /// Delete macro
  Future<void> deleteMacro(dynamic id) async {
    try {
      if (id is int) {
        await _apiService.init();
        await _apiService.delete('/macros/$id');
        await getMacros(); // Refresh
      } else {
        // Local-only - delete from cache
        final macros = await _getFromCache();
        macros.removeWhere((m) => m.id == id);
        await _cacheLocally(macros);
      }
    } catch (e) {
      debugPrint("Failed to delete macro: $e");
      // Fallback
      final macros = await _getFromCache();
      macros.removeWhere((m) => m.id == id);
      await _cacheLocally(macros);
    }
  }

  /// Reset to defaults and seed to cloud
  Future<void> resetToDefaults() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
    await prefs.remove(_migratedKey);
    await seedDefaultMacrosToCloud();
  }
  
  /// Seed default macros to cloud (for all users)
  Future<void> seedDefaultMacrosToCloud() async {
    try {
      final defaults = _defaultMacros();
      
      for (final macro in defaults) {
        try {
          await addMacro(macro);
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

  /// Migrate local macros to cloud (one-time for existing users)
  Future<void> migrateLocalToCloud() async {
    final prefs = await SharedPreferences.getInstance();
    final alreadyMigrated = prefs.getBool(_migratedKey) ?? false;
    
    if (!alreadyMigrated) {
      debugPrint("Migrating local macros to cloud...");
      final localMacros = await _getFromCache();
      
      for (final macro in localMacros) {
        try {
          await addMacro(macro);
        } catch (e) {
          debugPrint("Migration failed for ${macro.trigger}: $e");
        }
      }
      
      await prefs.setBool(_migratedKey, true);
      debugPrint("Migration complete");
    }
  }

  // === Private Helper Methods ===
  
  Future<List<MacroModel>> _getFromCache() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(_storageKey);
    
    if (data == null) {
      // No cache - return defaults and cache them
      final defaults = _defaultMacros();
      await _cacheLocally(defaults);
      return defaults;
    }
    
    try {
      final List<dynamic> decoded = jsonDecode(data);
      final macros = decoded.map((e) => MacroModel.fromJson(e)).toList();
      
      // Auto-upgrade legacy cache: if we detect the old hardcoded "📝 SOAP Note", replace with new AI Brain defaults.
      if (macros.any((m) => m.trigger == '📝 SOAP Note' && !m.isAiMacro)) {
        debugPrint("MacroService: Detected legacy macros in cache. Auto-upgrading to AI Brain defaults.");
        final defaults = _defaultMacros();
        await _cacheLocally(defaults);
        return defaults;
      }

      // Auto-upgrade: make sure the Free Note exists for users who already have the new defaults
      if (!macros.any((m) => m.trigger == '✨ Free Note')) {
        debugPrint("MacroService: '✨ Free Note' missing in cache. Auto-upgrading...");
        final defaults = _defaultMacros();
        final freeNoteMacro = defaults.firstWhere((m) => m.trigger == '✨ Free Note');
        macros.add(freeNoteMacro);
        await _cacheLocally(macros);
      }
      
      return macros;
    } catch (e) {
      return _defaultMacros();
    }
  }
  
  Future<void> _cacheLocally(List<MacroModel> macros) async {
    final prefs = await SharedPreferences.getInstance();
    final String data = jsonEncode(macros.map((e) => e.toJson()).toList());
    await prefs.setString(_storageKey, data);
  }
  
  Future<void> _updateLastSync() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());
  }

  Future<void> saveMacros(List<MacroModel> macros) async {
    await _cacheLocally(macros);
  }

  List<MacroModel> _defaultMacros() {
    return [
      MacroModel(
        id: '1',
        trigger: '📝 Classic SOAP',
        category: 'General',
        isFavorite: true,
        content: AIPromptConstants.templateClassicSoap,
        isAiMacro: true,
      ),
      MacroModel(
        id: '2',
        trigger: '🚨 ER SOAP',
        category: 'Emergency',
        isFavorite: true,
        content: AIPromptConstants.templateErSoap,
        isAiMacro: true,
      ),
      MacroModel(
        id: '3',
        trigger: '📞 SBAR Consult',
        category: 'Referral',
        isFavorite: false,
        content: AIPromptConstants.templateSbar,
        isAiMacro: true,
      ),
      MacroModel(
        id: '4',
        trigger: '📄 ER Discharge',
        category: 'Emergency',
        isFavorite: false,
        content: AIPromptConstants.templateDischarge,
        isAiMacro: true,
      ),
      MacroModel(
        id: '5',
        trigger: '🤒 Sick Leave',
        category: 'Admin',
        isFavorite: false,
        content: AIPromptConstants.templateSickLeave,
        isAiMacro: true,
      ),
      MacroModel(
        id: '6',
        trigger: '✨ Free Note',
        category: 'General',
        isFavorite: false,
        content: AIPromptConstants.templateFreeNote,
        isAiMacro: true,
      ),
    ];
  }
}


