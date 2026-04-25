// ============================================================
// GEMINI TRANSCRIPTION HELPER — Unified 2-Step Architecture
// ============================================================
// Single source of truth for Step 1 (Audio → Text) across ALL
// platforms: Desktop, Mobile, and Web Extension.
//
// USAGE:
//   final helper = GeminiTranscriptionHelper();
//   final transcript = await helper.transcribeFromPath(audioPath);
//   // or
//   final transcript = await helper.transcribeFromBytes(bytes, mimeType: 'audio/webm');
//
// WHY:
//   Before this helper, each platform had its own copy of:
//     - Audio byte loading (File vs HTTP blob)
//     - MIME type detection
//     - Gemini API call with goldenTranscriptionPrompt
//   Any bug fix had to be applied 3 times. Now it's in one place.
// ============================================================

import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:http/http.dart' as http;
import 'dart:io' show File, Platform;

import 'multimodal_ai_service.dart';
import 'ai_studio_multimodal_service.dart';
import 'package:soutnote/core/ai/ai_prompt_constants.dart';

/// Unified helper for Step 1 of the 2-Step Architecture.
/// Handles audio loading, MIME detection, and Gemini transcription
/// in a single, platform-aware call.
class GeminiTranscriptionHelper {
  // Singleton
  static final GeminiTranscriptionHelper _instance =
      GeminiTranscriptionHelper._internal();
  factory GeminiTranscriptionHelper() => _instance;
  GeminiTranscriptionHelper._internal();

  final MultimodalAIService _service = AIStudioMultimodalService();

  // ──────────────────────────────────────────────────────────
  // PUBLIC API
  // ──────────────────────────────────────────────────────────

  /// Transcribes audio from a file path (local) or blob URL (web).
  /// Returns the raw transcript text, or `null` on failure.
  Future<String?> transcribeFromPath(String audioPath) async {
    try {
      final bytes = await _loadAudioBytes(audioPath);
      if (bytes == null) {
        debugPrint(
            'GeminiTranscriptionHelper: Failed to load audio bytes from: $audioPath');
        return null;
      }
      final mimeType = detectMimeType(audioPath);
      return await _transcribe(bytes, mimeType);
    } catch (e) {
      debugPrint(
          'GeminiTranscriptionHelper: Exception in transcribeFromPath: $e');
      return null;
    }
  }

  /// Transcribes audio from raw bytes (useful when bytes are already loaded).
  /// Returns the raw transcript text, or `null` on failure.
  Future<String?> transcribeFromBytes(
    Uint8List bytes, {
    String mimeType = 'audio/webm',
  }) async {
    try {
      return await _transcribe(bytes, mimeType);
    } catch (e) {
      debugPrint(
          'GeminiTranscriptionHelper: Exception in transcribeFromBytes: $e');
      return null;
    }
  }

  // ──────────────────────────────────────────────────────────
  // INTERNAL HELPERS
  // ──────────────────────────────────────────────────────────

  /// Core transcription: sends audio + golden prompt to Gemini.
  Future<String?> _transcribe(Uint8List bytes, String mimeType) async {
    final result = await _service.transcribeAudio(
      audioBytes: bytes,
      mimeType: mimeType,
      globalPrompt: AIPromptConstants.goldenTranscriptionPrompt,
    );

    if (result.success && result.formattedNote.trim().isNotEmpty) {
      debugPrint('✅ GeminiTranscriptionHelper: Transcription complete '
          '(${result.formattedNote.length} chars, provider: ${result.providerName})');
      return result.formattedNote;
    }

    debugPrint(
        '⚠️ GeminiTranscriptionHelper: Transcription failed — ${result.errorMessage}');
    return null;
  }

  /// Loads audio bytes from either a blob URL (web) or a local file path.
  Future<Uint8List?> _loadAudioBytes(String path) async {
    if (kIsWeb) {
      // Web/PWA: path is a blob:// URL — fetch via HTTP
      try {
        final response = await http.get(Uri.parse(path));
        if (response.statusCode == 200) {
          return response.bodyBytes;
        }
        debugPrint(
            'GeminiTranscriptionHelper: HTTP ${response.statusCode} loading blob');
        return null;
      } catch (e) {
        debugPrint('GeminiTranscriptionHelper: Error fetching blob: $e');
        return null;
      }
    } else {
      // Mobile/Desktop: local file path
      try {
        final file = File(path);
        if (await file.exists()) {
          return await file.readAsBytes();
        }
        debugPrint('GeminiTranscriptionHelper: File not found: $path');
        return null;
      } catch (e) {
        debugPrint('GeminiTranscriptionHelper: Error reading file: $e');
        return null;
      }
    }
  }

  /// Detects MIME type from file extension or URL.
  /// Falls back to 'audio/webm' on web, 'audio/wav' on native.
  static String detectMimeType(String path) {
    final ext = path.split('.').last.toLowerCase();
    return switch (ext) {
      'm4a' => 'audio/m4a',
      'mp4' => 'audio/mp4',
      'webm' => 'audio/webm',
      'ogg' => 'audio/ogg',
      'aac' => 'audio/aac',
      'wav' => 'audio/wav',
      'mp3' => 'audio/mp3',
      _ => kIsWeb ? 'audio/webm' : 'audio/wav',
    };
  }
}
