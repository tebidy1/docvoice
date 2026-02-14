import 'package:isar/isar.dart';
import '../models/macro.dart';
import 'database_service.dart';
import 'dart:async';
import 'dart:convert';

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
      
      // 1. SOAP Note
      await addMacro(
        "📝 SOAP Note", 
        '''
SOAP NOTE

SUBJECTIVE:
• Chief Complaint: [Complaint]
• HPI: [History of Present Illness]
• ROS: [Relevant Systems / Negatives]

OBJECTIVE:
• Vitals: BP: [Value / mmHg] | HR: [Value / bpm] | Temp: [Value / °C]
• General Appearance: [Description]
• Systemic Exam: [Key Findings]

ASSESSMENT:
• Primary Diagnosis: [Dx]
• Differential: [DDx]

PLAN:
• Pharmacotherapy: [Medication Name] [Dose] [Freq] [Duration]
• Investigations: [Labs / Imaging]
• Follow-up: [Timeframe]

"Patient educated regarding diagnosis, plan, and red flags for ER return."
''', 
        category: "General"
      );
      print("MacroService: ✓ Added 'SOAP Note'");

      // 2. Sick Leave
      await addMacro(
        "🤒 Sick Leave", 
        '''
SICK LEAVE RECOMMENDATION

To: Employer / School Administrators

CLINICAL STATUS:
• Diagnosis: [Condition]

RECOMMENDATION:
"Based on the medical examination performed today, the above-named patient is found to be unfit for work/school."

• Duration: [Number] Days
• Starting From: [Start Date]
• Ending On: [End Date]

TREATING PHYSICIAN:
[Dr. Name]
[S.C.F.H.S License Number]
''', 
        category: "Admin"
      );
      print("MacroService: ✓ Added 'Sick Leave'");

      // 3. Medical Report
      await addMacro(
        "📄 Medical Report", 
        '''
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
        category: "Reports"
      );
      print("MacroService: ✓ Added 'Medical Report'");

      // 4. Referral
      await addMacro(
        "🏥 Referral", 
        '''
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
        category: "Referral"
      );
      print("MacroService: ✓ Added 'Referral'");

      // 5. Radiology Req
      await addMacro(
        "☢️ Radiology Req", 
        '''
RADIOLOGY REQUEST
Priority: [Routine / Urgent]


STUDY REQUESTED:
[Modality: X-Ray/CT/MRI] of [Body Part]
[Side: Left / Right / Bilateral]

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
        category: "Orders"
      );
      print("MacroService: ✓ Added 'Radiology Req'");

      // 6. Diabetic Follow-up
      await addMacro(
        "🩸 Diabetic Follow-up", 
        '''
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
        category: "Internal Medicine"
      );
      print("MacroService: ✓ Added 'Diabetic Follow-up'");

      // 7. Neuro Exam
      await addMacro(
        "🧠 Neuro Exam", 
        '''
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
        category: "Neurology"
      );
      print("MacroService: ✓ Added 'Neuro Exam'");

      // 8. Joint Exam
      await addMacro(
        "🦴 Joint Exam", 
        '''
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
        category: "Orthopedics"
      );
      print("MacroService: ✓ Added 'Joint Exam'");
      
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
