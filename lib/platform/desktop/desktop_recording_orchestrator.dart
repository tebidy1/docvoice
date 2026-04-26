import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/services/speech_transcription_service.dart';
import '../../core/services/audio_recorder_service.dart';
import '../../core/services/inbox_service.dart';
import '../../core/entities/note_model.dart';

class RecordingResult {
  final String text;
  final String? audioPath;
  final NoteModel? savedNote;

  RecordingResult({required this.text, this.audioPath, this.savedNote});
}

class DesktopRecordingOrchestrator extends ChangeNotifier {
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
  AudioRecorderService get recorder => _transcriptionService.recorder;

  // Result stream for transcription results
  final StreamController<RecordingResult> _resultController = StreamController<RecordingResult>.broadcast();
  Stream<RecordingResult> get resultStream => _resultController.stream;

  // Stream for instant text updates (for live streaming display)
  final StreamController<String> _liveTextController = StreamController<String>.broadcast();
  Stream<String> get liveTextStream => _liveTextController.stream;

  Future<void> initialize() async {
    // Basic initialization if needed
  }

  Future<String> getSttEngine() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('stt_engine_pref') ?? 'oracle_live';
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
        _liveTextController.add(text);
        final savedNote = await _inboxService.addNote(
          text,
          patientName: 'Untitled',
          summary: null,
        );
        _resultController.add(RecordingResult(text: text, savedNote: savedNote));
      }
    } catch (e) {
      debugPrint("Error stopping: $e");
      _isProcessing = false;
      notifyListeners();
    } finally {
      _isToggling = false;
    }
  }


  @override
  void dispose() {
    _transcriptionService.dispose();
    _resultController.close();
    _liveTextController.close();
    super.dispose();
  }
}