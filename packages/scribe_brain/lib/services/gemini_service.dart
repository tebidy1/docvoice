import 'package:google_generative_ai/google_generative_ai.dart';
import 'dart:convert';
import 'dart:math';
import 'dart:async';

class GeminiService {
  final String apiKey;
  late final GenerativeModel _model;

  GeminiService({required this.apiKey}) {
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

  /// Fast Mode: Text Only
  Future<String> formatText(String rawText, {String? macroContext, String? instruction, String? specialty, String? globalPrompt}) async {
    if (apiKey.isEmpty) return rawText;

    final prompt = '''
### ROLE & OBJECTIVE
You are an expert AI Medical Scribe. Merge the raw transcript into the template.
Produce a professional medical note.

### INPUTS
1. RAW TRANSCRIPT: "$rawText"
2. TEMPLATE: 
$macroContext

### INSTRUCTIONS
1. Fix ASR errors and terminology.
2. Use professional medical English.
3. Map info to template sections.
4. Leave missing fields as [Not Reported].
5. Output ONLY the note.

${globalPrompt != null ? '### GLOBAL GUIDELINES\n$globalPrompt\n' : ''}
${specialty != null ? '### CONTEXT\n$specialty\n' : ''}
''';

    try {
      final content = [Content.text(prompt)];
      final response = await _retryWithBackoff(() => _model.generateContent(content));
      return (response.text ?? rawText).replaceAll('```', '').trim();
    } catch (e) {
      print("Gemini formatText Error: $e");
      return rawText;
    }
  }

  /// Smart Mode: Text + Suggestions (JSON)
  Future<Map<String, dynamic>?> formatTextWithSuggestions(
    String rawText, {
    String? macroContext,
    String? specialty,
    String? globalPrompt,
  }) async {
    if (apiKey.isEmpty) {
      return {'final_note': rawText, 'missing_suggestions': []};
    }

    final prompt = '''
### ROLE & OBJECTIVE
You are an expert AI Medical Scribe.
1. Process raw transcript into a medical note based on the Template.
2. Identify missing clinical details.
3. Generate Quick-Add suggestions.

### INPUTS
1. RAW TRANSCRIPT: "$rawText"
2. TEMPLATE: 
$macroContext

### OUTPUT FORMAT (JSON ONLY)
{
  "final_note": "Full formatted note...",
  "missing_suggestions": [
    { "label": "Add BP", "text_to_insert": "BP is normal." },
    ...
  ]
}

### INSTRUCTIONS
- Same style rules as standard mode.
- Generate 3-5 clinically relevant suggestions for missing info.

${globalPrompt != null ? '### GLOBAL GUIDELINES\n$globalPrompt\n' : ''}
${specialty != null ? '### CONTEXT\n$specialty\n' : ''}
''';

    try {
      final model = GenerativeModel(
        model: 'gemini-2.5-flash',
        apiKey: apiKey,
        generationConfig: GenerationConfig(responseMimeType: 'application/json'),
      );
      
      final response = await _retryWithBackoff(() => model.generateContent([Content.text(prompt)]));
      final responseText = response.text;

      if (responseText == null || responseText.isEmpty) throw "Empty response";

      try {
        return jsonDecode(responseText) as Map<String, dynamic>;
      } catch (e) {
        // Fallback for markdown json
        final match = RegExp(r'```json\s*(.*?)\s*```', dotAll: true).firstMatch(responseText);
        if (match != null) {
          return jsonDecode(match.group(1)!);
        }
        return {'final_note': responseText, 'missing_suggestions': []};
      }
    } catch (e) {
      print("Gemini Smart Mode Error: $e");
      return null;
    }
  }
}
