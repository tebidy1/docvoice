import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/services/oci_realtime_service.dart';
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
  final OciRealtimeService _ociRealtimeService = OciRealtimeService();
  final SpeechTranscriptionService _batchTranscriptionService =
      SpeechTranscriptionService();
  final AudioRecorderService _recorderService = AudioRecorderService();
  final InboxService _inboxService = InboxService();

  StreamSubscription? _ociStatusSubscription;
  StreamSubscription? _ociTranscriptSubscription;

  bool _isRecording = false;
  bool _isProcessing = false;
  bool _isToggling = false;

  bool get isRecording => _isRecording;
  bool get isProcessing => _isProcessing;
  AudioRecorderService get recorder => _recorderService;
  OciRealtimeService get ociRealtimeService => _ociRealtimeService;

  Stream<Uint8List>? _pcmStream;
  StreamSubscription? _pcmSubscription;

  final StreamController<RecordingResult> _resultController =
      StreamController<RecordingResult>.broadcast();
  Stream<RecordingResult> get resultStream => _resultController.stream;

  final StreamController<String> _liveTextController =
      StreamController<String>.broadcast();
  Stream<String> get liveTextStream => _liveTextController.stream;

  Future<void> initialize() async {
    _ociStatusSubscription =
        _ociRealtimeService.statusStream.listen(_onOciStatusChanged);
    _ociTranscriptSubscription =
        _ociRealtimeService.transcriptStream.listen(_onOciTranscriptUpdate);

    _ociRealtimeService.prefetchToken().catchError((e) {
      debugPrint('Initial token prefetch failed: $e');
    });
  }

  void _onOciStatusChanged(RealtimeStatus status) {
    debugPrint('OCI Status changed: $status');
  }

  void _onOciTranscriptUpdate(String transcript) {
    _liveTextController.add(transcript);
  }

  Future<String> getSttEngine() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('stt_engine_pref') ?? 'oracle_live';
  }

  Future<void> startRecording() async {
    if (_isToggling) return;
    _isToggling = true;

    try {
      await _ociRealtimeService.prefetchToken();

      _ociRealtimeService.startPcmCollection();

      _pcmStream = await _recorderService.startRecording();

      _pcmSubscription = _pcmStream!.listen(
        (data) {
          _ociRealtimeService.addPcmChunk(data);
        },
        onError: (e) {
          debugPrint('PCM stream error: $e');
        },
        onDone: () {
          debugPrint('PCM stream done.');
          _ociRealtimeService.stopPcmCollection();
        },
      );

      _ociRealtimeService.startTranscription(_pcmStream!).catchError((e) {
        debugPrint(
            'Failed to start OCI realtime - will use batch fallback: $e');
      });

      _isRecording = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error starting recording: $e');
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

      _ociRealtimeService.requestFinalResult();

      await Future.delayed(const Duration(milliseconds: 500));

      final realtimeStatus = _ociRealtimeService.status;
      final realtimeTranscript = _ociRealtimeService.finalTranscript;

      if (realtimeStatus == RealtimeStatus.authenticated &&
          realtimeTranscript.trim().isNotEmpty) {
        debugPrint('Realtime transcription succeeded. Using live transcript.');
        _ociRealtimeService.stopTranscription();
        await _stopAudioRecording();

        final text = realtimeTranscript;
        _liveTextController.add(text);

        final savedNote = await _inboxService.addNote(
          text,
          patientName: 'Untitled',
          summary: null,
        );
        _resultController
            .add(RecordingResult(text: text, savedNote: savedNote));
      } else {
        debugPrint(
            'Realtime unavailable or empty transcript. Falling back to batch.');
        _ociRealtimeService.stopTranscription();
        await _stopAudioRecording();

        final text = await _batchFallback();

        if (text.trim().isNotEmpty) {
          _liveTextController.add(text);
          final savedNote = await _inboxService.addNote(
            text,
            patientName: 'Untitled',
            summary: null,
          );
          _resultController
              .add(RecordingResult(text: text, savedNote: savedNote));
        }
      }

      _isProcessing = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error stopping recording: $e');
      _isProcessing = false;
      notifyListeners();
    } finally {
      _isToggling = false;
    }
  }

  Future<void> _stopAudioRecording() async {
    await _pcmSubscription?.cancel();
    _pcmSubscription = null;
    _pcmStream = null;

    await _recorderService.stopRecording();
  }

  Future<String> _batchFallback() async {
    final wavBytes = _ociRealtimeService.pcmBufferAsWav;

    if (wavBytes.length <= 44) {
      throw Exception('No audio data captured for batch fallback');
    }

    debugPrint(
        'Batch fallback: WAV file from PCM buffer, ${wavBytes.length} bytes');

    final sttEngine = await getSttEngine();
    final language = sttEngine == 'oracle_medical' ? 'en' : 'en';

    _liveTextController.add('Transcribing audio (batch mode)...');

    return await _batchTranscriptionService.transcribeOracleBatch(
      fileBytes: wavBytes,
      filename: 'recording.wav',
      language: language,
      modelType: 'WHISPER_LARGE_V3T',
    );
  }

  @override
  void dispose() {
    _ociStatusSubscription?.cancel();
    _ociTranscriptSubscription?.cancel();
    _pcmSubscription?.cancel();
    _ociRealtimeService.dispose();
    _batchTranscriptionService.dispose();
    _recorderService.dispose();
    _resultController.close();
    _liveTextController.close();
    super.dispose();
  }
}
