import 'dart:typed_data';
import 'package:scribe_brain/models/processing_config.dart';
import 'package:scribe_brain/models/processed_note.dart';
import 'package:scribe_brain/services/groq_service.dart';
import 'package:scribe_brain/services/gemini_service.dart';
import 'package:scribe_brain/services/learning_service.dart';

class ProcessingEngine {
  final GroqService _groq;
  final GeminiService _gemini;
  final LearningService _learning = LearningService();
  
  ProcessingEngine({
    required String groqApiKey,
    required String geminiApiKey,
  }) : _groq = GroqService(apiKey: groqApiKey),
       _gemini = GeminiService(apiKey: geminiApiKey);
  
  /// Unified processing method that handles Transcription -> Learning -> AI Formatting
  Future<ProcessedNote> processRequest({
    Uint8List? audioBytes,
    String? rawTranscript,
    required ProcessingConfig config,
    String? macroContent,
    String? audioFilename, // Optional filename for transcription (e.g. recording.webm)
    bool skipAi = false,
  }) async {
    final startTime = DateTime.now();
    
    // Step 0: Apply Learning Context
    if (config.userPreferences != null && config.userPreferences!['global_prompt'] != null) {
      _learning.updateUserPrompt(config.userPreferences!['global_prompt']!);
    }
    final globalPrompt = _learning.getGlobalPrompt();

    // Step 1: Transcription (or use provided text)
    String textToProcess;
    Duration transcriptDuration = Duration.zero;
    String groqModelUsed = 'skipped';

    if (rawTranscript != null) {
      textToProcess = rawTranscript;
    } else if (audioBytes != null) {
      final transcriptStart = DateTime.now();
      final rawText = await _groq.transcribe(
        audioBytes,
        modelId: config.groqModel.modelId,
        filename: audioFilename ?? 'recording.m4a',
      );
      transcriptDuration = DateTime.now().difference(transcriptStart);
      textToProcess = rawText;
      groqModelUsed = config.groqModel.modelId;
    } else {
      throw "ProcessingEngine: Either audioBytes or rawTranscript must be provided.";
    }
    
    // Check for transcription error
    if (textToProcess.startsWith("Error:")) {
      return ProcessedNote(
        rawTranscript: textToProcess,
        formattedText: textToProcess, // Return error as formatted text
        processingTime: DateTime.now().difference(startTime),
        metrics: ProcessingMetrics(
          transcriptionTime: transcriptDuration,
          formattingTime: Duration.zero,
          groqModelUsed: groqModelUsed,
          geminiModeUsed: 'none',
        ),
      );
    }
    
    // Step 2: Formatting
    final formatStart = DateTime.now();
    String formattedText = "";
    List<Suggestion> suggestions = [];
    
    if (!skipAi) {
        // Determine Specialty context if present
        final specialty = config.userPreferences?['specialty'];

        if (config.geminiMode == GeminiMode.smart) {
          final result = await _gemini.formatTextWithSuggestions(
            textToProcess,
            macroContext: macroContent,
            specialty: specialty,
            globalPrompt: globalPrompt,
          );
          formattedText = result?['final_note'] ?? textToProcess;
          suggestions = (result?['missing_suggestions'] as List?)
              ?.map((s) => Suggestion(
                    label: s['label'],
                    textToInsert: s['text_to_insert'],
                  ))
              .toList() ?? [];
        } else {
          // Fast Mode
          formattedText = await _gemini.formatText(
            textToProcess,
            macroContext: macroContent,
            specialty: specialty,
            globalPrompt: globalPrompt,
          );
        }
    } else {
        formattedText = textToProcess; // If skipping AI, formatted is same as raw
    }
    final formatDuration = DateTime.now().difference(formatStart);
    
    return ProcessedNote(
      rawTranscript: textToProcess,
      formattedText: formattedText,
      suggestions: suggestions,
      processingTime: DateTime.now().difference(startTime),
      metrics: ProcessingMetrics(
        transcriptionTime: transcriptDuration,
        formattingTime: formatDuration,
        groqModelUsed: groqModelUsed,
        geminiModeUsed: config.geminiMode.name,
      ),
    );
  }
}
