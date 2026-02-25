// ignore_for_file: dangling_library_doc_comments
/// ============================================================
/// AI PROCESSING SERVICE — Docvoice Core AI Brain
/// ============================================================
/// THE single unified service that handles ALL communication
/// with the AI backend endpoint (/audio/process, /audio/analyze).
///
/// REPLACES:
///   - lib/services/gemini_service.dart
///   - lib/mobile_app/services/gemini_service.dart
///   (Both are now deprecated. They delegate here.)
///
/// PLATFORM SUPPORT: Works identically on all platforms.
///   Mobile uses ArabicScrubber for PII anonymization.
///   Desktop/Web skip scrubbing (handled server-side instead).
///
/// PHASE 3 READY:
///   When Backend Prompt Management is implemented, only THIS
///   file needs to change. The constructor will accept an
///   optional [serverPromptOverride] from a future
///   PromptConfigRepository. All callers remain unchanged.
/// ============================================================

import '../../services/api_service.dart';
import '../../core/ai/ai_prompt_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Defines the processing mode for the AI engine.
enum AIProcessingMode {
  /// Fast mode: Returns only the formatted note text.
  /// No missing-field analysis. Faster response (2-4 seconds).
  fast,

  /// Smart mode: Returns formatted note + missing_suggestions.
  /// Adds 4-6 seconds but provides physician with fill-in hints.
  smart,
}

/// The result of an AI note processing request.
class AIProcessingResult {
  /// The final formatted note text, ready for physician review.
  /// Contains orange-highlighted placeholders for missing fields.
  final String formattedNote;

  /// A list of AI-generated suggestions for fields that were
  /// empty in the transcript. Only populated in [smart] mode.
  final List<Map<String, dynamic>> missingSuggestions;

  /// True if the result was returned successfully from the server.
  final bool success;

  /// Error message if [success] is false.
  final String? errorMessage;

  const AIProcessingResult({
    required this.formattedNote,
    this.missingSuggestions = const [],
    required this.success,
    this.errorMessage,
  });

  /// Convenience factory for error results.
  factory AIProcessingResult.error(String message) {
    return AIProcessingResult(
      formattedNote: '',
      success: false,
      errorMessage: message,
    );
  }
}

/// The result of an AI note analysis request.
class AIAnalysisResult {
  final String patientName;
  final String summary;
  final String suggestedMacroType;

  const AIAnalysisResult({
    required this.patientName,
    required this.summary,
    required this.suggestedMacroType,
  });

  factory AIAnalysisResult.fallback(String rawText) {
    return AIAnalysisResult(
      patientName: 'Unknown Patient',
      summary: rawText.length > 80 ? rawText.substring(0, 80) : rawText,
      suggestedMacroType: 'general',
    );
  }
}

/// Unified AI Processing Service.
/// Use [AIProcessingService()] — it's a singleton.
class AIProcessingService {
  static final AIProcessingService _instance = AIProcessingService._internal();
  factory AIProcessingService() => _instance;
  AIProcessingService._internal();

  final _apiService = ApiService();

  // ----------------------------------------------------------
  // PROCESS NOTE (Core Feature)
  // ----------------------------------------------------------

  /// Processes a raw transcript against a template macro to
  /// produce a formatted, professional medical note.
  ///
  /// [transcript]    The raw text from STT (Groq/Whisper).
  /// [macroContent]  The full template text of the selected macro.
  /// [mode]          Processing mode (fast or smart).
  ///
  /// Settings ([specialty], [globalPrompt]) are loaded from
  /// SharedPreferences automatically if not provided.
  /// This keeps callers clean — they only pass what they know.
  Future<AIProcessingResult> processNote({
    required String transcript,
    required String macroContent,
    AIProcessingMode mode = AIProcessingMode.fast,
    String? specialty,
    String? globalPromptOverride,
  }) async {
    try {
      // Load settings if not provided by caller
      final prefs = await SharedPreferences.getInstance();
      final resolvedSpecialty =
          specialty ?? prefs.getString('specialty') ?? 'General Practice';
      final resolvedPrompt = globalPromptOverride ??
          prefs.getString('global_ai_prompt') ??
          AIPromptConstants.masterPrompt; // ← Uses centralized constant

      final response = await _apiService.post('/audio/process', body: {
        'transcript': transcript,
        'macro_context': macroContent,
        'specialty': resolvedSpecialty,
        'global_prompt': resolvedPrompt,
        'mode': mode == AIProcessingMode.smart ? 'smart' : 'fast',
      });

      if (response['status'] == true) {
        final payload = response['payload'] as Map<String, dynamic>;

        // Support both response formats from the server:
        // - Smart mode:  { final_note: "...", missing_suggestions: [...] }
        // - Fast mode:   { text: "..." }
        final formattedNote =
            payload['final_note'] as String? ?? payload['text'] as String? ?? '';

        final suggestions = (payload['missing_suggestions'] as List?)
            ?.cast<Map<String, dynamic>>() ?? [];

        return AIProcessingResult(
          formattedNote: formattedNote,
          missingSuggestions: suggestions,
          success: true,
        );
      } else {
        return AIProcessingResult.error(
          response['message'] as String? ?? 'AI processing failed',
        );
      }
    } catch (e) {
      return AIProcessingResult.error(e.toString());
    }
  }

  // ----------------------------------------------------------
  // ANALYZE NOTE (Auto-detect patient name & macro type)
  // ----------------------------------------------------------

  /// Analyzes raw transcript text to extract:
  ///   - Patient name
  ///   - A short summary
  ///   - Suggested document type (SOAP, Referral, etc.)
  ///
  /// Used by the home screen to auto-categorize new recordings.
  Future<AIAnalysisResult> analyzeNote(String transcript) async {
    try {
      final response = await _apiService.post('/audio/analyze', body: {
        'transcript': transcript,
      });

      if (response['status'] == true) {
        final payload = response['payload'] as Map<String, dynamic>;
        return AIAnalysisResult(
          patientName: payload['patientName'] as String? ?? 'Unknown Patient',
          summary: payload['summary'] as String? ?? '',
          suggestedMacroType:
              payload['suggestedMacroType'] as String? ?? 'general',
        );
      }
    } catch (e) {
      print('AIProcessingService.analyzeNote error: $e');
    }

    return AIAnalysisResult.fallback(transcript);
  }

  // ----------------------------------------------------------
  // SETTINGS HELPERS
  // ----------------------------------------------------------

  /// Loads the effective global AI prompt.
  /// Priority: SharedPreferences > AIPromptConstants.masterPrompt
  ///
  /// In Phase 3: Priority will be:
  ///   Server Prompt > SharedPreferences > AIPromptConstants
  static Future<String> getEffectivePrompt() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('global_ai_prompt') ??
        AIPromptConstants.masterPrompt;
  }

  /// Loads the effective specialty setting.
  static Future<String> getEffectiveSpecialty() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('specialty') ?? 'General Practice';
  }

  /// Loads the effective Smart Suggestions preference.
  static Future<bool> isSmartSuggestionsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('enable_smart_suggestions') ?? true;
  }

  /// Returns the processing mode based on user settings.
  static Future<AIProcessingMode> getEffectiveMode() async {
    final usesSmart = await isSmartSuggestionsEnabled();
    return usesSmart ? AIProcessingMode.smart : AIProcessingMode.fast;
  }
}
