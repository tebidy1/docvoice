import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';

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
      return decoded.map((e) => MacroModel.fromJson(e)).toList();
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
        trigger: '📝 SOAP Note',
        category: 'General',
        isFavorite: true,
        content: '''
SOAP NOTE

SUBJECTIVE:
• Chief Complaint: [ Select ]
• HPI: [ Select ]
• ROS: [ Select ]

OBJECTIVE:
• Vitals: BP: [ Select ] | HR: [ Select ] | Temp: [ Select ]
• General Appearance: [ Select ]
• Systemic Exam: [ Select ]

ASSESSMENT:
• Primary Diagnosis: [ Select ]
• Differential: [ Select ]

PLAN:
• Pharmacotherapy: [ Select ]
• Investigations: [ Select ]
• Follow-up: [ Select ]

"Patient educated regarding diagnosis, plan, and red flags for ER return."
''',
      ),
      MacroModel(
        id: '2',
        trigger: '🤒 Sick Leave',
        category: 'Admin',
        isFavorite: true,
        content: '''
SICK LEAVE RECOMMENDATION

To: Employer / School Administrators

CLINICAL STATUS:
• Diagnosis: [ Select ]

RECOMMENDATION:
"Based on the medical examination performed today, the above-named patient is found to be unfit for work/school."

• Duration: [ Select ] Days
• Starting From: [ Select ]
• Ending On: [ Select ]

TREATING PHYSICIAN:
[Dr. Name]
[S.C.F.H.S License Number]
''',
      ),
      MacroModel(
        id: '3',
        trigger: '📄 Medical Report',
        category: 'Reports',
        content: '''
MEDICAL REPORT
Date: [Date]

TO WHOM IT MAY CONCERN,

HISTORY & COURSE:
[Detailed Clinical History and Progression]

CLINICAL FINDINGS:
[Examination Findings]

INVESTIGATIONS:
[Significant Lab/Radiology Results]

FINAL DIAGNOSIS:
[Diagnosis]

PLAN & RECOMMENDATIONS:
[Current Management Plan]

"This report is issued upon the request of the patient for administrative purposes."
''',
      ),
      MacroModel(
        id: '4',
        trigger: '🏥 Referral',
        category: 'Referral',
        content: '''
REFERRAL LETTER

TO: [Specialty Department]
AT: [Receiving Hospital Name]

FROM: [Referring Doctor Name]
DATE: [Date]


REASON FOR REFERRAL:
[Specific Clinical Question or Service Needed]

CLINICAL SUMMARY:
[Brief History of Present Illness]
[Relevant Past Medical History]

CURRENT MEDICATIONS:
[List]

PENDING RESULTS:
[Outstanding Labs/Images]

"Thank you for accepting this patient for further management."
''',
      ),
      MacroModel(
        id: '5',
        trigger: '☢️ Radiology Req',
        category: 'Orders',
        content: '''
RADIOLOGY REQUEST
Priority: [Routine / Urgent]


STUDY REQUESTED:
• Modality: [ Select ] - [ Select ]
• Side: [ Select ]

CLINICAL INDICATION:
[Symptoms / Rule Out Diagnosis]

SPECIFIC QUERY TO RADIOLOGIST:
[What exactly are we looking for?]

SAFETY CHECKLIST:
• Pregnancy Status: [Yes / No / N/A]
• Renal Function (eGFR/Cr): [Value / Not Indicated]
• Contrast Allergy: [Denied / Present]

"I certify that this examination is clinically indicated."
''',
      ),
      // --- Internal Medicine ---
      MacroModel(
        id: '6',
        trigger: '🩸 Diabetic Follow-up',
        category: 'Internal Medicine',
        content: '''
DIABETES FOLLOW-UP

SUBJECTIVE:
• Home Glucose Readings: [Range / Control]
• Hypoglycemia Episodes: [Yes / No]
• Compliance: [Good / Poor]
• Symptoms: [Polydipsia, Polyuria, Blurring Vision]

OBJECTIVE:
• Vitals: BP: [BP] | BMI: [Value]
• Exam: [Foot Exam / Neuro / CV]
• Labs: HbA1c: [Value]% | Kidney Function: [Value]

ASSESSMENT:
• Diabetes Type [1/2]: [Control Status]
• Complications: [None / Neuropathy / etc]

PLAN:
• Medications: [Adjustments]
• Lifestyle: [Diet / Exercise]
• Follow-up: [Interval]
''',
      ),
      // --- Neurology ---
      MacroModel(
        id: '7',
        trigger: '🧠 Neuro Exam',
        category: 'Neurology',
        content: '''
NEUROLOGICAL EXAMINATION

MENTAL STATUS:
• GCS: [Score / 15]
• Orientation: [Time, Place, Person]
• Speech: [Normal / Dysarthric / Aphasic]

CRANIAL NERVES:
• Pupils: [Size / Reactivity]
• Face: [Symmetry]
• Other: [Deficits]

MOTOR SYSTEM:
• Tone: [Normal / Increased / Decreased]
• Power (Upper): R:[Grade/5] L:[Grade/5]
• Power (Lower): R:[Grade/5] L:[Grade/5] 
• Reflexes: [Run-down]

SENSORY:
• Light Touch/Pinprick: [Intact / Deficit Level]
• Proprioception: [Intact / Impaired]

COORDINATION & GAIT:
• Finger-Nose: [Normal / Dysmetria]
• Gait: [Normal / Ataxic / Hemiplegic]

IMPRESSION:
[Localization of Lesion]
''',
      ),
      // --- Orthopedics ---
      MacroModel(
        id: '8',
        trigger: '🦴 Joint Exam',
        category: 'Orthopedics',
        content: '''
ORTHOPEDIC JOINT EXAMINATION
Joint: [Shoulder / Knee / Hip / etc]
Side: [Right / Left]

INSPECTION:
• Swelling: [Yes / No]
• Deformity: [Description]
• Skin: [Scars / Erythema]

PALPATION:
• Tenderness: [Specific Landmark]
• Temperature: [Normal / Warm]
• Effusion: [Present / Absent]

RANGE OF MOTION (ROM):
• Active: [Degree]
• Passive: [Degree]
• Pain on Motion: [Yes / No]

SPECIAL TESTS:
[Test Name]: [Positive / Negative]

NEUROVASCULAR:
• Pulses: [Palpable]
• Sensation: [Intact]

PLAN:
[Imaging / Conservative / Surgical]
''',
      ),
    ];
  }
}
