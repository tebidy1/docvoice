import 'package:google_generative_ai/google_generative_ai.dart';
import 'dart:convert';
import 'dart:math';
import 'dart:async';

class GeminiService {
  final String apiKey;
  late final GenerativeModel _model;

  GeminiService({required this.apiKey}) {
    // Using Gemini 2.5 Flash (latest, fastest, most capable)
    _model = GenerativeModel(
      model: 'gemini-1.5-flash', // Use 1.5 Flash as it is stable in Vertex AI/Studio
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

  Future<String> formatText(String rawText, {String? macroContext, String? instruction, String? specialty, String? globalPrompt}) async {
    if (apiKey.isEmpty || apiKey.contains("...")) {
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

${globalPrompt != null ? '### GLOBAL USER GUIDELINES\n$globalPrompt\n' : ''}
${specialty != null ? '### MEDICAL SPECIALTY CONTEXT\n$specialty\n' : ''}
${instruction != null ? '### SPECIFIC INSTRUCTIONS\n$instruction\n' : ''}

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
    if (apiKey.isEmpty || apiKey.contains("...")) {
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
      
      // Use JSON response mode for cleaner output (if supported by model, otherwise prompt relies on it)
      // Note: 1.5 Flash supports responseMimeType: 'application/json'
      final model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: apiKey,
        generationConfig: GenerationConfig(
          responseMimeType: 'application/json',
        ),
      );
      
      final response = await _retryWithBackoff(() => model.generateContent([Content.text(prompt)]));
      final responseText = response.text;

      if (responseText == null || responseText.isEmpty) {
        print("GeminiService: Empty response");
        return null;
      }

      // Parse JSON response
      try {
        final jsonResponse = jsonDecode(responseText) as Map<String, dynamic>;
        return jsonResponse;
      } catch (parseError) {
        print("GeminiService: JSON parse error: $parseError");
        // Fallback: try to extract JSON from markdown code blocks
        final jsonMatch = RegExp(r'```json\s*(.*?)\s*```', dotAll: true).firstMatch(responseText);
        if (jsonMatch != null) {
          final jsonResponse = jsonDecode(jsonMatch.group(1)!) as Map<String, dynamic>;
          return jsonResponse;
        }
        return {
          'final_note': responseText,
          'missing_suggestions': [],
        };
      }
    } catch (e) {
      print("GeminiService: Error during generation: $e");
      return null;
    }
  }
}
