// ============================================================
// MULTIMODAL AI — ABSTRACT INTERFACE (Repository Pattern)
// ============================================================
// Part of: lib/features/multimodal_ai/
//
// PURPOSE:
//   Defines the contract that EVERY AI provider must implement.
//   The UI layer always depends on THIS interface, never on a
//   concrete implementation directly.
//
// CURRENT IMPLEMENTATIONS:
//   ✅ AIStudioMultimodalService  — Google AI Studio (API Key)
//                                   → File: ai_studio_multimodal_service.dart
//
// FUTURE IMPLEMENTATIONS:
//   🔜 VertexAIMultimodalService  — Google Vertex AI, Saudi region
//                                   (IAM / Service Account auth — no API Key)
//                                   → File: vertex_ai_multimodal_service.dart (TODO)
//
//   🔜 BackendMultimodalService   — Routes through docapi.sootnote.com
//                                   (No SDK needed — pure HTTP proxy)
//                                   → File: backend_multimodal_service.dart (TODO)
//
// HOW TO SWITCH PROVIDERS:
//   Change only the concrete class wired up in your DI / Provider
//   setup. UI code never changes.
// ============================================================

import 'dart:typed_data';
import 'multimodal_ai_result.dart';

/// Abstract contract for multimodal (audio + text) AI note processing.
///
/// All providers must implement this interface so the UI layer
/// remains completely decoupled from the underlying AI platform.
abstract class MultimodalAIService {
  /// Processes a raw audio recording together with a medical template
  /// to produce a fully formatted professional clinical note.
  ///
  /// Parameters:
  /// - [audioBytes]    : Raw bytes of the recorded audio file (WAV / M4A).
  /// - [mimeType]      : MIME type of the audio (e.g. `audio/wav`, `audio/m4a`).
  /// - [macroContent]  : The full template text the physician selected.
  /// - [globalPrompt]  : The master AI directive / system prompt.
  /// - [specialty]     : The physician's specialty (context for the model).
  ///
  /// Returns a [MultimodalAIResult] — always, never throws.
  /// Check [MultimodalAIResult.success] before using the note.
  Future<MultimodalAIResult> processAudioNote({
    required Uint8List audioBytes,
    required String mimeType,
    required String macroContent,
    required String globalPrompt,
    required String specialty,
  });

  /// Extracts verbatim text transcript from raw audio without formatting it into a template.
  /// Used in the 2-step transcription architecture.
  Future<MultimodalAIResult> transcribeAudio({
    required Uint8List audioBytes,
    required String mimeType,
    required String globalPrompt,
  });

  /// Human-friendly name of this provider, for logging and UI badges.
  /// Example: "Google AI Studio (gemini-2.5-flash)"
  String get providerDisplayName;
}






