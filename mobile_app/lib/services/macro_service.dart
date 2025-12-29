import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class MacroModel {
  String id;
  String trigger;
  String content;
  bool isFavorite;
  String category;

  MacroModel({
    required this.id, 
    required this.trigger, 
    required this.content,
    this.isFavorite = false,
    this.category = 'General',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'trigger': trigger,
    'content': content,
    'isFavorite': isFavorite,
    'category': category,
  };

  factory MacroModel.fromJson(Map<String, dynamic> json) {
    return MacroModel(
      id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      trigger: json['trigger'] ?? "",
      content: json['content'] ?? "",
      isFavorite: json['isFavorite'] ?? false,
      category: json['category'] ?? "General",
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

  Future<void> resetToDefaults() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
    await getMacros();
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
      ),
      MacroModel(
        id: '2',
        trigger: '🤒 Sick Leave',
        category: 'Admin',
        isFavorite: true,
        content: '''
SICK LEAVE RECOMMENDATION

To: Employer / School Administrators

PATIENT DETAILS:
• Name: [Patient Name]
• ID / Iqama: [Number]
• Date of Visit: [Date]

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
      ),
      MacroModel(
        id: '3',
        trigger: '📄 Medical Report',
        category: 'Reports',
        content: '''
MEDICAL REPORT
Date: [Date]

TO WHOM IT MAY CONCERN,

PATIENT IDENTIFICATION:
• Name: [Name]
• MRN: [ID]
• DOB: [Date]

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

PATIENT: [Name] | ID: [Number]

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

PATIENT: [Name] | ID: [Number]

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
      ),
      // --- Internal Medicine ---
      MacroModel(
        id: '6',
        trigger: '🩸 Diabetic Follow-up',
        category: 'Internal Medicine',
        content: '''
DIABETES FOLLOW-UP
Patient: [Name] | ID: [ID]

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
Patient: [Name] | ID: [ID]

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
