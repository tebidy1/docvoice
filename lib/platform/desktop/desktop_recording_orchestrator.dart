import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/entities/inbox_note.dart';
import '../../core/services/audio_recorder_service.dart';
import '../../core/services/audio_chunker_service.dart';
import '../../core/services/connectivity_server.dart';
import '../../core/services/inbox_service.dart';
import '../../core/services/whisper_asset_service.dart';
import '../../core/services/whisper_isolate_service.dart';
import '../../core/services/oracle_live_speech_service.dart';
import '../../core/services/oci_request_signer.dart';

class RecordingResult {
  final String text;
  final String? audioPath;
  final NoteModel? savedNote;

  RecordingResult({required this.text, this.audioPath, this.savedNote});
}

class DesktopRecordingOrchestrator extends ChangeNotifier {
  // Services
  final AudioRecorderService _recorder = AudioRecorderService();
  final InboxService _inboxService = InboxService();
  final ConnectivityServer _server = ConnectivityServer();

  // State
  bool _isRecording = false;
  bool _isProcessing = false;
  bool _isWhisperModelLoading = false;
  bool _isToggling = false;

  // Oracle streaming
  OracleLiveSpeechService? _oracleService;
  Future<String>? _oracleTranscriptFuture;

  // Gemini One-Shot
  String? _geminiOneShotPath;

  // Offline Whisper
  WhisperIsolateService? _whisperService;
  AudioChunkerService? _audioChunker;
  StreamSubscription? _whisperRecordSub;

  // Connectivity server streams
  Stream<dynamic> get serverTextStream => _server.textStream;
  Stream<dynamic> get serverAudioStream => _server.audioStream;
  Stream<String> get serverStatusStream => _server.statusStream;

  // Getters
  bool get isRecording => _isRecording;
  bool get isProcessing => _isProcessing;
  bool get isWhisperModelLoading => _isWhisperModelLoading;
  AudioRecorderService get recorder => _recorder;

  // Result stream for transcription results
  final StreamController<RecordingResult> _resultController = StreamController<RecordingResult>.broadcast();
  Stream<RecordingResult> get resultStream => _resultController.stream;

  // Stream for instant text updates (for live streaming display)
  final StreamController<String> _liveTextController = StreamController<String>.broadcast();
  Stream<String> get liveTextStream => _liveTextController.stream;

  Future<void> initialize() async {
    await _server.startServer();

    _server.statusStream.listen((status) {
      if (status.startsWith("Error")) {
        _isProcessing = false;
        notifyListeners();
      }
    });

    _server.audioStream.listen((audioChunk) {
      debugPrint("Received Audio Chunk: ${audioChunk.length} bytes");
    });

    _server.textStream.listen((text) async {
      _isProcessing = false;
      notifyListeners();

      if (text.trim().isEmpty) {
        debugPrint("Skipping: Text is empty");
        return;
      }

      debugPrint("Received transcription: '$text'");

      try {
        final savedNote = await _inboxService.addNote(
          text,
          patientName: 'Untitled',
          summary: null,
        );
        _resultController.add(RecordingResult(text: text, savedNote: savedNote));
        debugPrint("Added to Inbox (Server)");
      } catch (e) {
        debugPrint('Error adding valid note to inbox: $e');
        _resultController.add(RecordingResult(text: text));
      }
    });
  }

  Future<String> getSttEngine() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('stt_engine_pref') ?? 'oracle_live';
  }

  Future<void> startRecording() async {
    if (_isToggling) return;
    _isToggling = true;

    try {
      if (!await _recorder.hasPermission()) {
        debugPrint("Permission denied");
        return;
      }

      final sttEngine = await getSttEngine();

      if (sttEngine == 'offline_whisper') {
        await _startOfflineWhisperRecording();
      } else if (sttEngine == 'oracle_live') {
        await _startOracleRecording();
      } else if (sttEngine == 'gemini_oneshot') {
        await _startGeminiOneShotRecording();
      } else {
        await _startStandardWavRecording();
      }
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
      final sttEngine = await getSttEngine();

      if (sttEngine == 'offline_whisper') {
        await _stopOfflineWhisperRecording();
      } else if (sttEngine == 'oracle_live') {
        await _stopOracleRecording();
      } else if (sttEngine == 'gemini_oneshot') {
        await _stopGeminiOneShotRecording();
      } else {
        await _stopStandardWavRecording();
      }
    } catch (e) {
      debugPrint("Error stopping: $e");
      _isProcessing = false;
      notifyListeners();
    } finally {
      _isToggling = false;
    }
  }

  Future<void> _startOfflineWhisperRecording() async {
    try {
      _isWhisperModelLoading = true;
      _isProcessing = true;
      notifyListeners();

      _whisperService = WhisperIsolateService();
      final modelPath = await WhisperAssetService.getModelPath();
      await _whisperService!.initialize(modelPath);

      debugPrint('[OfflineWhisper] Model loaded, starting recording...');

      _isWhisperModelLoading = false;
      _isProcessing = false;
      notifyListeners();

      _audioChunker = AudioChunkerService(
        whisperService: _whisperService!,
        onChunkTranscribed: (text) {
          debugPrint('[OfflineWhisper] Chunk: $text');
          _liveTextController.add(text);
        },
        onError: (error) {
          debugPrint('[OfflineWhisper] Error: $error');
        },
      );
      _audioChunker!.start();

      final audioStream = await _recorder.startRecording();
      _whisperRecordSub = audioStream.listen((data) {
        _audioChunker?.feedPcm16(data);
      });

      _isRecording = true;
      notifyListeners();

    } catch (e) {
      debugPrint('[OfflineWhisper] Start error: $e');
      _whisperRecordSub?.cancel();
      _whisperRecordSub = null;
      _audioChunker?.dispose();
      _audioChunker = null;
      await _whisperService?.dispose();
      _whisperService = null;

      _isWhisperModelLoading = false;
      _isProcessing = false;
      _isRecording = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> _stopOfflineWhisperRecording() async {
    try {
      debugPrint('[OfflineWhisper] === STOP FLOW STARTED ===');

      _isRecording = false;
      notifyListeners();

      _whisperRecordSub?.cancel();
      _whisperRecordSub = null;
      try {
        await _recorder.stopRecording().timeout(const Duration(milliseconds: 500));
      } catch (e) {
        debugPrint('[OfflineWhisper] Recorder stop error (ignored): $e');
      }
      debugPrint('[OfflineWhisper] Step 1: Microphone stopped.');

      try {
        if (_audioChunker != null) {
          await _audioChunker!.flush().timeout(const Duration(seconds: 180));
        }
      } catch (e) {
        debugPrint('[OfflineWhisper] Flush timeout/error: $e');
      }

      final transcript = _audioChunker?.fullTranscript ?? '';
      debugPrint('[OfflineWhisper] Step 4: Full transcript: ${transcript.length} chars');

      if (transcript.trim().isNotEmpty) {
        _liveTextController.add(transcript);
        final savedNote = await _inboxService.addNote(transcript,
            patientName: 'Untitled', summary: null);
        _resultController.add(RecordingResult(text: transcript, savedNote: savedNote));
        debugPrint('[OfflineWhisper] ✅ Note saved to inbox');
      } else {
        debugPrint('[OfflineWhisper] ⚠️ No speech detected');
        _liveTextController.addError(Exception('No speech detected.'));
        _resultController.add(RecordingResult(text: ''));
      }

      debugPrint('[OfflineWhisper] Step 5: Cleaning up...');
      _audioChunker?.dispose();
      _audioChunker = null;
      final serviceToDispose = _whisperService;
      _whisperService = null;
      serviceToDispose?.dispose().catchError((e) => debugPrint('Dispose error: $e'));

      debugPrint('[OfflineWhisper] === STOP FLOW COMPLETED ===');
    } catch (e) {
      debugPrint('[OfflineWhisper] Stop error: $e');
      _audioChunker?.dispose();
      _audioChunker = null;
      final serviceToDispose = _whisperService;
      _whisperService = null;
      serviceToDispose?.dispose().catchError((e) => debugPrint('Dispose error: $e'));
      _isProcessing = false;
      notifyListeners();
    }
  }

  Future<void> _startOracleRecording() async {
    final prefs = await SharedPreferences.getInstance();
    final useWhisper = prefs.getBool('oracle_use_whisper_model') ?? true;
    final creds = OciCredentials(
      tenancyId: 'ocid1.tenancy.oc1..aaaaaaaadt3eulxchu6ygrisqsai4z6qji5dyqiam7tgwgd6rrxe2wsocp2a',
      userId: 'ocid1.user.oc1..aaaaaaaa3ykq2ykgaixlhze3yip5m3fxrsbkghnzecezym7c7neqk57fupdq',
      fingerprint: 'a6:24:f0:9f:9a:f0:77:18:c5:85:2d:03:90:02:6d:c2',
      compartmentId: 'ocid1.tenancy.oc1..aaaaaaaadt3eulxchu6ygrisqsai4z6qji5dyqiam7tgwgd6rrxe2wsocp2a',
      privateKeyPem: '''-----BEGIN PRIVATE KEY-----
FO0CkxoBB/Ko9g0hLQx0lw+B3kwEtb0+vXG6c/lNxP9sv0+uTkEYYOpmqaRIHZWh
525iMEn66cJYUlSMD1nRjnw5YOqzF/bjg2R7w1jLAoGBAIN+zY0VUwMoPSrD84lP
PX/UnDv9wjrl95oGxuahSW3LfrrLXGdeN4KAL2IFMQLhghu7O3G72DHM3LboUWQm
OONRokqHJyqd1n1fNXCCk8wUJJSAVzv3atnDtxP1Vs03yhwL6OkBnr+jyvRT/VSf
cQBOFhw1ZkYvxx4A6HSNxyae
-----END PRIVATE KEY-----''',
    );

    _oracleService = OracleLiveSpeechService(
      credentials: creds,
      model: useWhisper
          ? OracleSTTModel.whisperGeneric
          : OracleSTTModel.oracleMedical,
      language: 'ar',
      onError: (e) {
        debugPrint("Oracle Stream Error: $e");
      },
    );

    final audioStream = await _recorder.startRecording();
    _oracleTranscriptFuture = _oracleService!.startSession(audioStream);

    _isRecording = true;
    notifyListeners();
  }

  Future<void> _stopOracleRecording() async {
    if (_oracleService != null && _oracleTranscriptFuture != null) {
      try {
        _isRecording = false;
        _isProcessing = true;
        notifyListeners();

        try {
          await _recorder.stopRecording().timeout(const Duration(milliseconds: 500));
        } catch (e) {
          debugPrint("AudioRecorder stop timeout/error ignored: $e");
        }

        final text = await _oracleService!.stopSession();
        if (text.isNotEmpty) {
          _liveTextController.add(text);
          final savedNote = await _inboxService.addNote(text,
              patientName: 'Untitled', summary: null);
          _resultController.add(RecordingResult(text: text, savedNote: savedNote));
        } else {
          debugPrint("Warning: Oracle returned empty transcript");
          _liveTextController.addError(Exception("No speech detected."));
          _resultController.add(RecordingResult(text: ''));
        }
      } catch (e) {
        debugPrint("Oracle Streaming Error: $e");
        _liveTextController.addError(e);
        _resultController.add(RecordingResult(text: ''));
      } finally {
        _oracleService = null;
        _oracleTranscriptFuture = null;
        _isProcessing = false;
        notifyListeners();
      }
    } else {
      try {
        await _recorder.stopRecording();
      } catch (_) {}
      _isProcessing = false;
      notifyListeners();
    }
  }

  Future<void> _startGeminiOneShotRecording() async {
    final dir = await getTemporaryDirectory();
    final ext = Platform.isWindows ? 'flac' : 'm4a';
    final path = '${dir.path}/oneshot_${DateTime.now().millisecondsSinceEpoch}.$ext';
    await _recorder.startRecordingCompressed(path);
    _geminiOneShotPath = path;
    debugPrint("Gemini One-Shot recording started at: $path");
    _isRecording = true;
    notifyListeners();
  }

  Future<void> _stopGeminiOneShotRecording() async {
    final oneShotPath = await _recorder.stop();
    if (oneShotPath != null) {
      debugPrint("Gemini One-Shot recording stopped at: $oneShotPath");

      _isRecording = false;
      _isProcessing = false;
      notifyListeners();

      _geminiOneShotPath = oneShotPath;
      final savedNote = await _inboxService.addNote(
        'لا يوجد نص اصلي عند اختيار هذا النموذج',
        patientName: 'Untitled',
        summary: null,
        audioPath: oneShotPath,
      );

      _resultController.add(RecordingResult(
        text: 'لا يوجد نص اصلي عند اختيار هذا النموذج',
        audioPath: oneShotPath,
        savedNote: savedNote,
      ));
    }
  }

  Future<void> _startStandardWavRecording() async {
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/temp_recording.wav';
    await _recorder.startRecordingToFile(path);
    debugPrint("Recording started successfully to $path");
    _isRecording = true;
    notifyListeners();
  }

  Future<void> _stopStandardWavRecording() async {
    final path = await _recorder.stop();
    _isRecording = false;
    _isProcessing = true;
    notifyListeners();

    if (path != null) {
      debugPrint("Recording saved to: $path");
      final file = File(path);

      if (!await file.exists()) {
        _isProcessing = false;
        notifyListeners();
        return;
      }

      final bytes = await file.readAsBytes();
      debugPrint("Read ${bytes.length} bytes from recording file");

      try {
        await _server.transcribeWav(bytes);
      } catch (e) {
        _liveTextController.addError(e);
        _isProcessing = false;
        notifyListeners();
      }

      await file.delete();
    } else {
      debugPrint("ERROR: Recorder returned null path");
      _isProcessing = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _server.stopServer();
    _whisperRecordSub?.cancel();
    _audioChunker?.dispose();
    _whisperService?.dispose();
    _resultController.close();
    _liveTextController.close();
    super.dispose();
  }
}