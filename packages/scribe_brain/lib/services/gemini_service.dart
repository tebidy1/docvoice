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
      safetySettings: [
        SafetySetting(HarmCategory.harassment, HarmBlockThreshold.none),
        SafetySetting(HarmCategory.hateSpeech, HarmBlockThreshold.none),
        SafetySetting(HarmCategory.sexuallyExplicit, HarmBlockThreshold.none),
        SafetySetting(HarmCategory.dangerousContent, HarmBlockThreshold.none),
      ],
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
    // 🔧 DEBUG: Validate API Key
    if (apiKey.isEmpty || apiKey.contains('your_') || apiKey.contains('placeholder')) {
      print('❌ GEMINI ERROR: Invalid or placeholder API key detected');
      print('   API Key: ${apiKey.isEmpty ? "(empty)" : "${apiKey.substring(0, min(10, apiKey.length))}..."}');
      throw Exception('Invalid Gemini API key. Please configure a valid key in Settings or .env file');
    }

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

    print('🔧 DEBUG: Sending request to Gemini');
    print('   Prompt length: ${prompt.length} chars');
    print('   Raw text length: ${rawText.length} chars');
    print('   Template provided: ${macroContext != null}');

    try {
      final content = [Content.text(prompt)];
      final response = await _retryWithBackoff(() => _model.generateContent(content));
      
      final text = response.text;
      if (text == null) {
         print('❌ GEMINI BLOCKED: Response text is null. Safety Settings?');
         if (response.promptFeedback != null) {
            print('   Prompt Feedback: ${response.promptFeedback?.blockReason}');
         }
         throw Exception("Gemini blocked the response (Safety Filter).");
      }

      final result = text.replaceAll('```', '').trim();
      
      print('✅ GEMINI SUCCESS: Response received');
      print('   Result length: ${result.length} chars');
      print('   Changed: ${result != rawText}');
      
      return result;
    } catch (e) {
      print('❌ GEMINI ERROR: $e');
      print('   Stack trace: ${StackTrace.current}');
      rethrow; // Don't silently return rawText - let caller handle error
    }
  }

  /// Smart Mode: Text + Suggestions (JSON)
  Future<Map<String, dynamic>?> formatTextWithSuggestions(
    String rawText, {
    String? macroContext,
    String? specialty,
    String? globalPrompt,
  }) async {
    // 🔧 DEBUG: Validate API Key
    if (apiKey.isEmpty || apiKey.contains('your_') || apiKey.contains('placeholder')) {
      print('❌ GEMINI SMART MODE ERROR: Invalid API key');
      throw Exception('Invalid Gemini API key for Smart Mode');
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

    print('🔧 DEBUG SMART MODE: Sending request to Gemini');
    print('   High Accuracy Mode: ENABLED');
    print('   Expecting JSON response with suggestions');

    try {
      final model = GenerativeModel(
        model: 'gemini-2.5-flash',
        apiKey: apiKey,
        generationConfig: GenerationConfig(responseMimeType: 'application/json'),
        safetySettings: [
          SafetySetting(HarmCategory.harassment, HarmBlockThreshold.none),
          SafetySetting(HarmCategory.hateSpeech, HarmBlockThreshold.none),
          SafetySetting(HarmCategory.sexuallyExplicit, HarmBlockThreshold.none),
          SafetySetting(HarmCategory.dangerousContent, HarmBlockThreshold.none),
        ],
      );
      
      final response = await _retryWithBackoff(() => model.generateContent([Content.text(prompt)]));
      final responseText = response.text;

      if (responseText == null || responseText.isEmpty) throw "Empty response";

      print('✅ GEMINI SMART MODE SUCCESS');
      print('   Response length: ${responseText.length}');

      try {
        final parsed = jsonDecode(responseText) as Map<String, dynamic>;
        print('   Suggestions count: ${(parsed['missing_suggestions'] as List?)?.length ?? 0}');
        return parsed;
      } catch (e) {
        print('⚠️  JSON Parse failed, trying markdown extraction');
        // Fallback for markdown json
        final match = RegExp(r'```json\s*(.*?)\s*```', dotAll: true).firstMatch(responseText);
        if (match != null) {
          return jsonDecode(match.group(1)!);
        }
        return {'final_note': responseText, 'missing_suggestions': []};
      }
    } catch (e) {
      print('❌ GEMINI SMART MODE ERROR: $e');
      print('   Stack trace: ${StackTrace.current}');
      rethrow; // Don't return null silently
    }
  }
}
