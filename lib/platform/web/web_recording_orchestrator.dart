import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/speech_transcription_service.dart';
import '../../data/services/inbox_service_api.dart';
import '../../core/entities/note_model.dart';

class RecordingResult {
  final String text;
  final String? audioPath;
  final NoteModel? savedNote;

  RecordingResult({required this.text, this.audioPath, this.savedNote});
}

class WebRecordingOrchestrator extends ChangeNotifier {
  // Services
  final SpeechTranscriptionService _transcriptionService = SpeechTranscriptionService();
  final InboxService _inboxService = InboxService();

  // State
  bool _isRecording = false;
  bool _isProcessing = false;
  bool _isToggling = false;

  // Getters
  bool get isRecording => _isRecording;
  bool get isProcessing => _isProcessing;
  SpeechTranscriptionService get transcriptionService => _transcriptionService;

  // Result stream for transcription results
  final StreamController<RecordingResult> _resultController = StreamController<RecordingResult>.broadcast();
  Stream<RecordingResult> get resultStream => _resultController.stream;

  Future<void> initialize() async {
    await _inboxService.init();
  }

  Future<void> startRecording() async {
    if (_isToggling) return;
    _isToggling = true;

    try {
      await _transcriptionService.startRecording();
      _isRecording = true;
      notifyListeners();
    } catch (e) {
      debugPrint("Error recording: $e");
      _isRecording = false;
      _isProcessing = false;
      notifyListeners();
      rethrow;
    } finally {
      _isToggling = false;
    }
  }

  Future<void> stopRecording() async {
    if (_isToggling) return;
    _isToggling = true;

    try {
      _isRecording = false;
      _isProcessing = true;
      notifyListeners();

      final text = await _transcriptionService.stopAndTranscribe();
      
      if (text.trim().isNotEmpty) {
        final savedNote = await _inboxService.addNote(
          text,
          patientName: 'Web Note',
          summary: null,
        );
        _resultController.add(RecordingResult(text: text, savedNote: savedNote));
      }
      
      _isProcessing = false;
      notifyListeners();
    } catch (e) {
      debugPrint("Error stopping: $e");
      _isProcessing = false;
      notifyListeners();
      rethrow;
    } finally {
      _isToggling = false;
    }
  }

  @override
  void dispose() {
    _transcriptionService.dispose();
    _resultController.close();
    super.dispose();
  }
}
