import 'package:google_generative_ai/google_generative_ai.dart';
import 'dart:convert';
import 'dart:math';
import 'dart:async';

class GeminiService {
  final String apiKey;
  late final GenerativeModel _model;

  GeminiService({required this.apiKey}) {
    // Using Gemini 2.5 Flash (latest, fastest, most capable) - Matching Desktop
    _model = GenerativeModel(
      model: 'gemini-2.5-flash', 
      apiKey: apiKey,
    );
  }

  Future<GenerateContentResponse> _retryWithBackoff(Future<GenerateContentResponse> Function() operation, {int maxRetries = 3}) async {
    int retryCount = 0;
    while (true) {
      try {
        return await operation();
      } catch (e) {
        if (e.toString().contains('503') || e.toString().toLowerCase().contains('overloaded')) {
          if (retryCount >= maxRetries) rethrow;
          retryCount++;
          final delay = Duration(seconds: pow(2, retryCount).toInt());
          print("GeminiService: 503 Overloaded. Retrying in ${delay.inSeconds}s... (Attempt $retryCount/$maxRetries)");
          await Future.delayed(delay);
        } else {
          rethrow;
        }
      }
    }
  }

  /// Analyzes raw note text and extracts patient name, summary, and suggests macro type
  /// Matches Desktop implementation
  Future<Map<String, dynamic>> analyzeNote(String rawText) async {
    if (apiKey.isEmpty || apiKey.contains("your_gemini_api_key")) {
      return {
        'patientName': 'Unknown Patient',
        'summary': rawText.substring(0, rawText.length > 50 ? 50 : rawText.length),
        'suggestedMacroType': 'general'
      };
    }

    final prompt = '''
You are an AI assistant analyzing medical dictation notes. Extract the following information from the text below and return ONLY a JSON object (no other text):

{
  "patientName": "extracted patient name or 'Unknown Patient' if not found",
  "summary": "a brief 1-line summary (max 60 characters)",
  "suggestedMacroType": "one of: 'follow-up', 'soap', 'referral', 'prescription', 'vital-signs', 'general'"
}

Rules for suggestion:
- "follow-up" if mentions follow-up, next visit, or monitoring
- "soap" if structured as subjective/objective/assessment/plan
- "referral" if mentions "refer to", "consult", or "Dr."
- "prescription" if mentions medication, dosage, or Rx
- "vital-signs" if primarily about BP, HR, temp, etc.
- "general" for everything else

Text to analyze:
"$rawText"

Return ONLY the JSON object, no markdown, no explanation.
''';

    try {
      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      final text = response.text ?? '{}';
      
      // Clean up response
      String cleanJson = text.trim();
      if (cleanJson.startsWith('```json')) {
        cleanJson = cleanJson.substring(7);
      }
      if (cleanJson.startsWith('```')) {
        cleanJson = cleanJson.substring(3);
      }
      if (cleanJson.endsWith('```')) {
        cleanJson = cleanJson.substring(0, cleanJson.length - 3);
      }
      
      final result = jsonDecode(cleanJson.trim());
      return result;
    } catch (e) {
      print("Gemini analyzeNote Error: $e");
      return {
        'patientName': 'Unknown Patient',
        'summary': rawText.substring(0, rawText.length > 50 ? 50 : rawText.length),
        'suggestedMacroType': 'general'
      };
    }
  }

  Future<String> formatText(String rawText, {String? macroContext, String? instruction, String? specialty, String? globalPrompt}) async {
    if (apiKey.isEmpty || apiKey.contains("your_gemini_api_key")) {
      return rawText; // Fallback if no key
    }

    final prompt = '''
### ROLE & OBJECTIVE
You are an expert AI Medical Scribe and Clinical Documentation Specialist.
Your task is to take a raw, unstructured audio transcript from a doctor and merge it into a specific medical template (Macro).
You must produce a final, polished, professional medical note ready for the EMR (Electronic Medical Record).

### INPUTS
1. {RAW_TRANSCRIPT}: The spoken text from the doctor. It may contain speech-to-text errors, filler words (umm, ah), repetition, and casual language.
2. {SELECTED_TEMPLATE}: The structured format the doctor wants to use.

### CORE INSTRUCTIONS

1. **Information Extraction & Mapping:**
   - Extract all relevant clinical information from the {RAW_TRANSCRIPT}.
   - Map this information intelligently to the corresponding sections in the {SELECTED_TEMPLATE}.
   - If the transcript mentions details not present in the template structure, append them to the most logical section (usually 'History' or 'Plan').

2. **ASR Error Correction & Medical Terminology:**
   - Fix all speech-to-text errors based on medical context.
     - Example: "Hyper tension" -> "Hypertension"
     - Example: "Met for min" -> "Metformin"
     - Example: "Patient asma" -> "Patient has asthma"
   - Capitalize brand name drugs (e.g., Panadol, Lasix) and keep generic names lowercase (e.g., metformin, amlodipine) unless starting a sentence.
   - Standardize units (e.g., convert "milligrams" to "mg", "degrees" to "°C").

3. **Style & Tone Transformation:**
   - Convert casual spoken language into formal, concise medical English.
   - Use standard medical abbreviations where appropriate.
   - Remove all filler words, pleasantries, or non-clinical conversation.

4. **Handling Missing Information (CRITICAL):**
   - If a specific field in the {SELECTED_TEMPLATE} (like [BP_Value]) is NOT mentioned in the {RAW_TRANSCRIPT}:
     - DO NOT HALLUCINATE or invent a number.
     - Leave the placeholder as is (e.g., [Not Reported]) OR remove the line entirely if it makes the note look cleaner.
     - NEVER output "I don't know" or "The doctor didn't say".

5. **Output Format:**
   - Output ONLY the final note.
   - Do not add conversational filler like "Here is the note:" or "I have processed the text."

${globalPrompt != null ? '### GLOBAL USER GUIDELINES\\n$globalPrompt\\n' : ''}
${specialty != null ? '### MEDICAL SPECIALTY CONTEXT\\n$specialty\\n' : ''}
${instruction != null ? '### SPECIFIC INSTRUCTIONS\\n$instruction\\n' : ''}

### EXAMPLES

**Input Transcript:**
"patient is sarah, 30 years old. umm came in with a sore throat for 3 days. fever is 38.5. no cough. looks like tonsillitis. i gave her augmentin 1g twice a day for a week. also panadol for pain."

**Template:**
SUBJECTIVE: [History of Present Illness]
OBJECTIVE: Temp: [Temp], Exam: [Findings]
ASSESSMENT: [Diagnosis]
PLAN: [Medications]

**Target Output:**
SUBJECTIVE: Patient is a 30-year-old female presenting with a 3-day history of sore throat. Reports fever. Denies cough.
OBJECTIVE: Temp: 38.5°C. Exam: Consistent with tonsillitis.
ASSESSMENT: Tonsillitis.
PLAN:
1. Augmentin 1g PO BID for 7 days.
2. Panadol PRN for pain control.

---
### BEGIN PROCESSING
Target Template:
${macroContext ?? "No specific template provided. Organize professionally."}

Raw Transcript:
$rawText
''';

    try {
      final content = [Content.text(prompt)];
      final response = await _retryWithBackoff(() => _model.generateContent(content));
      final result = response.text ?? rawText;
      
      // Clean up any markdown formatting that might have been added
      return result
          .replaceAll('```', '')
          .replaceAll('markdown', '')
          .trim();
    } catch (e) {
      print("Gemini formatText Error: $e");
      return rawText; // Fallback to raw text
    }
  }

  /// Format text with AI-generated suggestions for missing information
  /// Returns Map with 'final_note' and 'missing_suggestions' keys
  Future<Map<String, dynamic>?> formatTextWithSuggestions(
    String rawText, {
    String? macroContext,
    String? specialty,
    String? globalPrompt,
  }) async {
    if (apiKey.isEmpty || apiKey.contains("your_gemini_api_key")) {
      return {
        'final_note': rawText,
        'missing_suggestions': [],
      };
    }

    final prompt = '''
### ROLE & OBJECTIVE
You are an expert AI Medical Scribe and Clinical Documentation Specialist.
Your task is to:
1. Process a raw audio transcript into a professional medical note based on a specific Template.
2. Identify CRITICAL missing information based on the template fields and standard medical practice.
3. Generate actionable "Quick-Add" suggestions for these missing details.

### INPUTS
1. {RAW_TRANSCRIPT}: The spoken text from the doctor.
2. {SELECTED_TEMPLATE}: The structured format the doctor wants to use.

### CORE INSTRUCTIONS

1. **Information Extraction & Mapping:**
   - Extract relevant clinical info and map it to the {SELECTED_TEMPLATE}.
   - If details are missing for a specific template field, LEAVE IT BLANK or use a placeholder like [Not Reported] in the note. DO NOT hallucinate facts.

2. **ASR Error Correction & Terminology:**
   - Fix speech errors (e.g., "Hyper tension" -> "Hypertension").
   - Standardize units and capitalize brand name drugs.

3. **Style & Tone:**
   - Use formal, concise medical English. Remove filler words.

4. **Suggestion Generation Logic (New Feature):**
   - Analyze the transcript against the template.
   - Identify 3-5 distinct pieces of information that are missing but are clinically relevant (e.g., Vitals, Side of pain, Smoking status, Duration).
   - Create a suggestion for each missing item consisting of:
     - "label": A very short button text (e.g., "Add BP", "No Fever").
     - "text_to_insert": The full sentence to append if clicked (e.g., "Blood pressure is normal.", "Patient denies fever.").
   - Also, suggest common negative findings if not mentioned (e.g., "Denies allergies").

### OUTPUT FORMAT (CRITICAL)
You must output a **Single Valid JSON Object** with no markdown formatting. The structure must be:
{
  "final_note": "The full, formatted medical note string...",
  "missing_suggestions": [
    {
      "label": "Short Label",
      "text_to_insert": "Full text to insert."
    },
    ...
  ]
}

### EXAMPLE

**Input Transcript:**
"patient ahmed sore throat fever 38"

**Template:**
Subjective: [HPI]
Objective: BP: [BP], Temp: [Temp]

**Target JSON Output:**
{
  "final_note": "Subjective: Patient Ahmed presents with sore throat.\\nObjective: BP: [Not Reported], Temp: 38°C.",
  "missing_suggestions": [
    { "label": "Add BP: 120/80", "text_to_insert": "BP: 120/80 mmHg." },
    { "label": "Add: No Cough", "text_to_insert": "Patient denies cough." },
    { "label": "Add: Tonsils Normal", "text_to_insert": "Tonsils are not enlarged." }
  ]
}

---
### BEGIN PROCESSING
Target Template:
${macroContext ?? '[No template provided]'}

Raw Transcript:
$rawText

${specialty != null && specialty.isNotEmpty ? 'Medical Specialty: $specialty' : ''}
${globalPrompt != null && globalPrompt.isNotEmpty ? '\nAdditional Instructions: $globalPrompt' : ''}
''';

    try {
      print("GeminiService: Generating with suggestions...");
      
      // Use JSON response mode for cleaner output
      final model = GenerativeModel(
        model: 'gemini-2.5-flash',
        apiKey: apiKey,
        generationConfig: GenerationConfig(
          responseMimeType: 'application/json',
        ),
      );
      
      final response = await _retryWithBackoff(() => model.generateContent([Content.text(prompt)]));
      final responseText = response.text;

      if (responseText == null || responseText.isEmpty) {
        throw "Empty response";
      }

      // Parse JSON response
      try {
        final jsonResponse = jsonDecode(responseText) as Map<String, dynamic>;
        print("GeminiService: Successfully parsed JSON");
        return jsonResponse;
      } catch (parseError) {
        // Fallback: try to extract JSON from markdown code blocks
        final jsonMatch = RegExp(r'```json\s*(.*?)\s*```', dotAll: true).firstMatch(responseText);
        if (jsonMatch != null) {
          final jsonResponse = jsonDecode(jsonMatch.group(1)!) as Map<String, dynamic>;
          return jsonResponse;
        }
        // Final fallback: return text-only response
        return {
          'final_note': responseText.replaceAll('```json', '').replaceAll('```', '').trim(),
          'missing_suggestions': [],
        };
      }
    } catch (e) {
      print("GeminiService: Error during generation: $e");
      return null;
    }
  }
}
