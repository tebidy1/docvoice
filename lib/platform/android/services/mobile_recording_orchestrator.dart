import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/speech_transcription_service.dart';
import '../../../core/services/audio_recorder_service.dart';
import '../../../core/services/inbox_service.dart';
import '../../../core/entities/note_model.dart';
import '../../../core/network/api_client.dart';
import '../../../data/services/groq_service.dart';
import 'sherpa_local_service.dart';
import '../../../core/services/multimodal_ai/gemini_transcription_helper.dart';

class RecordingResult {
  final String text;
  final String? audioPath;
  final NoteModel? savedNote;

  RecordingResult({required this.text, this.audioPath, this.savedNote});
}

class MobileRecordingOrchestrator extends ChangeNotifier {
  final SpeechTranscriptionService _transcriptionService =
      SpeechTranscriptionService();
  final InboxService _inboxService = InboxService();

  bool _isRecording = false;
  bool _isProcessing = false;
  bool _isToggling = false;

  bool get isRecording => _isRecording;
  bool get isProcessing => _isProcessing;
  SpeechTranscriptionService get transcriptionService =>
      _transcriptionService;
  AudioRecorderService get recorder => _transcriptionService.recorder;

  final StreamController<RecordingResult> _resultController =
      StreamController<RecordingResult>.broadcast();
  Stream<RecordingResult> get resultStream => _resultController.stream;

  final StreamController<String> _liveTextController =
      StreamController<String>.broadcast();
  Stream<String> get liveTextStream => _liveTextController.stream;

  String? _currentRecordingPath;

  Future<String> getSttEngine() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('stt_engine_pref') ?? 'oracle_live';
  }

  Future<void> initialize() async {
    await _inboxService.init();
  }

  Future<void> startRecording() async {
    if (_isToggling) return;
    _isToggling = true;

    try {
      final sttEngine = await getSttEngine();

      if (sttEngine == 'oracle_live') {
        await _transcriptionService.startRecording();
      } else {
        await _startFileRecording();
      }

      _isRecording = true;
      notifyListeners();
    } catch (e) {
      debugPrint("Error starting recording: $e");
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

      final sttEngine = await getSttEngine();
      String text;

      if (sttEngine == 'oracle_live') {
        text = await _transcriptionService.stopAndTranscribe();
      } else {
        text = await _stopAndTranscribeFile(sttEngine);
      }

      if (text.trim().isNotEmpty) {
        _liveTextController.add(text);
        final savedNote = await _inboxService.addNote(
          text,
          patientName: 'Untitled',
          summary: null,
          audioPath: _currentRecordingPath,
        );
        _resultController.add(RecordingResult(
          text: text,
          audioPath: _currentRecordingPath,
          savedNote: savedNote,
        ));
      }
    } catch (e) {
      debugPrint("Error stopping recording: $e");
    } finally {
      _isProcessing = false;
      _isToggling = false;
      _currentRecordingPath = null;
      notifyListeners();
    }
  }

  Future<void> _startFileRecording() async {
    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final sttEngine = await getSttEngine();

    String extension = 'wav';
    if (sttEngine == 'gemini_oneshot') {
      extension = 'm4a';
    }

    _currentRecordingPath =
        p.join(tempDir.path, 'recording_$timestamp.$extension');

    if (sttEngine == 'gemini_oneshot') {
      await recorder.startRecordingCompressed(_currentRecordingPath!);
    } else {
      await recorder.startRecordingToFile(_currentRecordingPath!);
    }
  }

  Future<String> _stopAndTranscribeFile(String sttEngine) async {
    final path = await recorder.stop();
    if (path == null || path.isEmpty) {
      if (_currentRecordingPath != null) {
        return await _transcribeFile(_currentRecordingPath!, sttEngine);
      }
      throw Exception('Recording failed: no file path returned');
    }
    _currentRecordingPath = path;
    return await _transcribeFile(path, sttEngine);
  }

  Future<String> _transcribeFile(String audioPath, String sttEngine) async {
    try {
      switch (sttEngine) {
        case 'whisper_local':
          return await _transcribeLocal(audioPath);
        case 'groq':
          return await _transcribeGroq(audioPath);
        case 'gemini_oneshot':
          return await _transcribeGemini(audioPath);
        default:
          return await _transcribeGroq(audioPath);
      }
    } catch (e) {
      debugPrint("Transcription error ($sttEngine): $e");
      return '';
    }
  }

  Future<String> _transcribeLocal(String audioPath) async {
    final sherpaService = SherpaLocalService();
    await sherpaService.initialize();
    final result = await sherpaService.transcribeAudioFile(audioPath);
    if (result.startsWith('Error')) {
      throw Exception(result);
    }
    return result;
  }

  Future<String> _transcribeGroq(String audioPath) async {
    final file = File(audioPath);
    if (!await file.exists()) throw Exception('Audio file not found');
    final bytes = await file.readAsBytes();

    final prefs = await SharedPreferences.getInstance();
    final groqKey = prefs.getString('groq_api_key') ??
        (dotenv.isInitialized ? dotenv.env['GROQ_API_KEY'] ?? '' : '');

    if (groqKey.isNotEmpty) {
      final groqService = GroqService(apiKey: groqKey);
      final result = await groqService.transcribe(bytes,
          filename: p.basename(audioPath));
      if (!result.startsWith('Error')) return result;
    }

    final apiClient = ApiClient();
    final result = await apiClient.multipartPost(
      '/audio/transcribe',
      fileBytes: bytes,
      filename: p.basename(audioPath),
    );
    if (result['status'] == true) {
      return result['payload']['text'] ?? '';
    }
    throw Exception(result['message'] ?? 'Transcription failed');
  }

  Future<String> _transcribeGemini(String audioPath) async {
    final file = File(audioPath);
    if (!await file.exists()) throw Exception('Audio file not found');
    final bytes = await file.readAsBytes();
    final mimeType = GeminiTranscriptionHelper.detectMimeType(audioPath);
    final transcript = await GeminiTranscriptionHelper()
        .transcribeFromBytes(bytes, mimeType: mimeType);
    return transcript ?? '';
  }

  Future<double> getAmplitude() async {
    final amp = await _transcriptionService.getAmplitude();
    return amp;
  }

  @override
  void dispose() {
    _transcriptionService.dispose();
    _resultController.close();
    _liveTextController.close();
    super.dispose();
  }
}
