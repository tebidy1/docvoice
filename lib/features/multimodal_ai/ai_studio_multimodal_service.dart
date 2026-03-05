// ============================================================
// MULTIMODAL AI — GOOGLE AI STUDIO IMPLEMENTATION
// ============================================================
// Part of: lib/features/multimodal_ai/
//
// Provider : Google AI Studio (ai.google.dev)
// Auth     : API Key from .env → GEMINI_API_KEY
// Model    : gemini-2.5-flash  (multimodal — audio + text)
// SDK      : package:google_generative_ai
//
// WHY DIRECT SDK & NOT BACKEND?
//   Audio bytes are sent directly Browser/App → Google.
//   This avoids an extra network hop (App→Backend→Google→Backend→App)
//   and reduces latency significantly for real-time workflows.
//
// MIGRATION PATH:
//   When switching to Vertex AI (Saudi region):
//   1. Create VertexAIMultimodalService implementing MultimodalAIService
//   2. Replace only the DI wiring — no UI changes needed.
// ============================================================

import 'dart:typed_data';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'multimodal_ai_result.dart';
import 'multimodal_ai_service.dart';

/// Google AI Studio implementation of [MultimodalAIService].
///
/// Uses `gemini-2.5-flash` to process audio + template in a
/// single multimodal request — no separate STT step required.
class AIStudioMultimodalService implements MultimodalAIService {
  // ── Constants ────────────────────────────────────────────────────────────

  /// The Gemini model to use for multimodal processing.
  /// Update this constant when a newer model becomes available.
  static const String _modelId = 'gemini-2.5-flash';

  /// Provider name shown in UI badges and logs.
  static const String _providerName = 'Google AI Studio ($_modelId)';

  // ── Interface ─────────────────────────────────────────────────────────────

  @override
  String get providerDisplayName => _providerName;

  @override
  Future<MultimodalAIResult> processAudioNote({
    required Uint8List audioBytes,
    required String mimeType,
    required String macroContent,
    required String globalPrompt,
    required String specialty,
  }) async {
    try {
      // ── 1. Resolve API Key ─────────────────────────────────────────────
      // Priority: SharedPreferences → .env → error
      final apiKey = await _resolveApiKey();
      if (apiKey.isEmpty) {
        return MultimodalAIResult.error(
          'Gemini API Key is not configured.\n'
          'Go to Settings → AI Settings and enter your Google AI Studio key.',
          provider: _providerName,
        );
      }

      // ── 2. Initialize the Generative Model ────────────────────────────
      final model = GenerativeModel(
        model: _modelId,
        apiKey: apiKey,
        // Safety settings: Use defaults for medical content
        // (Gemini is trained to handle clinical descriptions)
      );

      // ── 3. Build the Multimodal Prompt ────────────────────────────────
      // We build one coherent prompt that combines:
      //   a) Master directive (global_prompt)
      //   b) Physician specialty context
      //   c) The selected template (macro_content)
      //   d) An instruction to listen to the audio
      final textPrompt = _buildPrompt(
        globalPrompt: globalPrompt,
        specialty: specialty,
        macroContent: macroContent,
      );

      // ── 4. Compose the Multimodal Content ─────────────────────────────
      // gemini-2.5-flash can receive audio bytes directly (< 20 MB).
      // No need for Files API (which is for larger or async uploads).
      //
      // DataPart attaches the raw audio bytes alongside the text prompt.
      // The model will transcribe AND format in a single inference pass.
      final content = Content.multi([
        TextPart(textPrompt),
        DataPart(mimeType, audioBytes),
      ]);

      // ── 5. Send Request & Parse Response ──────────────────────────────
      final response = await model.generateContent([content]);

      final rawText = response.text ?? '';

      if (rawText.trim().isEmpty) {
        return MultimodalAIResult.error(
          'The AI model returned an empty response. '
          'This may happen if the audio was not recognized. '
          'Please try again or check your audio recording.',
          provider: _providerName,
        );
      }

      return MultimodalAIResult(
        formattedNote: rawText.trim(),
        success: true,
        providerName: _providerName,
      );
    } on GenerativeAIException catch (e) {
      // API-level errors (quota exceeded, invalid key, model unavailable)
      return MultimodalAIResult.error(
        'Gemini API Error: ${e.message}',
        provider: _providerName,
      );
    } catch (e) {
      return MultimodalAIResult.error(
        'Unexpected error: $e',
        provider: _providerName,
      );
    }
  }

  // ── Private Helpers ───────────────────────────────────────────────────────

  /// Resolves the Gemini API key from the available sources.
  /// Priority: SharedPreferences (user-entered) > .env (developer default).
  Future<String> _resolveApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    final fromPrefs = prefs.getString('gemini_api_key') ?? '';
    if (fromPrefs.isNotEmpty) return fromPrefs;

    final fromEnv = dotenv.isInitialized ? dotenv.env['GEMINI_API_KEY'] ?? '' : '';
    return fromEnv;
  }

  /// Builds the text-part of the multimodal prompt.
  ///
  /// The prompt instructs the model to:
  /// 1. Listen to the attached audio recording.
  /// 2. Transcribe it accurately (fixing ASR/phonetic errors).
  /// 3. Fill the provided medical template with the transcribed content.
  /// 4. Use [Not Reported] for any template field not mentioned in the audio.
  String _buildPrompt({
    required String globalPrompt,
    required String specialty,
    required String macroContent,
  }) {
    return '''
$globalPrompt

PHYSICIAN SPECIALTY CONTEXT: $specialty

TASK:
You are listening to a real medical voice recording from a physician.
1. Transcribe the audio accurately. Correct phonetic errors and medical terminology mistakes.
2. Fill the following medical template using ONLY the information mentioned in the recording.
3. For any field in the template that the physician did NOT mention, write [Not Reported].
4. Output ONLY the completed template — no introduction, no summary, no extra commentary.

MEDICAL TEMPLATE TO FILL:
$macroContent

AUDIO RECORDING:
[See attached audio data]
''';
  }
}
