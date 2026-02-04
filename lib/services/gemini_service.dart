import 'api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GeminiService {
  final ApiService _apiService = ApiService();

  GeminiService({String? apiKey});

  /// Analyzes raw note text and extracts patient name, summary, and suggests macro type
  Future<Map<String, dynamic>> analyzeNote(String rawText) async {
    try {
      final response = await _apiService.post('/audio/analyze', body: {
        'transcript': rawText,
      });

      if (response['status'] == true) {
        return response['payload'] as Map<String, dynamic>;
      }
    } catch (e) {
      print("Gemini analyzeNote Error: $e");
    }

    return {
      'patientName': 'Unknown Patient',
      'summary': rawText.substring(0, rawText.length > 50 ? 50 : rawText.length),
      'suggestedMacroType': 'general'
    };
  }

  Future<String> formatText(String rawText, {
    String? macroContext, 
    String? instruction, 
    String? specialty, 
    String? globalPrompt
  }) async {
    try {
      final response = await _apiService.post('/audio/process', body: {
        'transcript': rawText,
        'macro_context': macroContext,
        'instruction': instruction,
        'specialty': specialty,
        'global_prompt': globalPrompt,
        'mode': 'fast',
      });

      if (response['status'] == true) {
        return response['payload']['text'] ?? rawText;
      }
    } catch (e) {
      print("Gemini formatText Error: $e");
    }
    return rawText;
  }

  /// Ask a question about the context
  Future<String> askQuestion(String contextText, String question) async {
    // Note: We don't have a specific askQuestion endpoint on backend yet, 
    // but we can use the process endpoint with a custom prompt if needed.
    // For now, return a placeholder or implement in backend.
    return "Question-answering is being migrated to backend.";
  }

  /// Format text with AI-generated suggestions for missing information
  Future<Map<String, dynamic>?> formatTextWithSuggestions(
    String rawText, {
    String? macroContext,
    String? specialty,
    String? globalPrompt,
  }) async {
    try {
      final response = await _apiService.post('/audio/process', body: {
        'transcript': rawText,
        'macro_context': macroContext,
        'specialty': specialty,
        'global_prompt': globalPrompt,
        'mode': 'smart',
      });

      if (response['status'] == true) {
        return response['payload'] as Map<String, dynamic>;
      }
    } catch (e) {
      print("Gemini formatTextWithSuggestions Error: $e");
    }
    return null;
  }
}
