import 'dart:async';
import 'dart:io' show File, Platform;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../network/api_client.dart';
import 'audio_recorder_service.dart';

enum SpeechTranscriptionState {
  idle,
  recording,
  uploading,
  processing,
  done,
  error,
}

class SpeechTranscriptionService {
  final AudioRecorderService _recorder = AudioRecorderService();
  final ApiClient _apiClient = ApiClient();

  AudioRecorderService get recorder => _recorder;

  SpeechTranscriptionState _state = SpeechTranscriptionState.idle;
  SpeechTranscriptionState get state => _state;

  void Function(SpeechTranscriptionState)? onStateChange;

  String? _currentRecordingPath;
  Timer? _pollingTimer;

  void _updateState(SpeechTranscriptionState newState) {
    _state = newState;
    onStateChange?.call(_state);
  }

  Future<void> startRecording() async {
    if (_state != SpeechTranscriptionState.idle && _state != SpeechTranscriptionState.done && _state != SpeechTranscriptionState.error) {
      return;
    }

    try {
      String path = '';
      if (!kIsWeb) {
        final tempDir = await getTemporaryDirectory();
        final String extension;
        if (Platform.isWindows) {
          extension = 'flac';
        } else if (Platform.isAndroid || Platform.isIOS) {
          extension = 'm4a';
        } else {
          extension = 'wav';
        }
        path = p.join(tempDir.path, 'transcription_${DateTime.now().millisecondsSinceEpoch}.$extension');
      }
      _currentRecordingPath = path;

      await _recorder.startRecordingCompressed(_currentRecordingPath!);
      _updateState(SpeechTranscriptionState.recording);
    } catch (e) {
      debugPrint('Error starting recording: $e');
      _updateState(SpeechTranscriptionState.error);
      rethrow;
    }
  }

  Future<String> stopAndTranscribe({String language = 'ar'}) async {
    if (_state != SpeechTranscriptionState.recording) {
      throw Exception('Not recording');
    }

    try {
      final path = await _recorder.stop();
      if (path == null) throw Exception('Recording failed, no file path returned');

      _updateState(SpeechTranscriptionState.uploading);

      final Uint8List fileBytes;
      if (kIsWeb) {
        final response = await _apiClient.getDirect(path);
        fileBytes = response.bodyBytes;
      } else {
        fileBytes = await File(path).readAsBytes();
      }
      
      final filename = kIsWeb ? 'recording.webm' : p.basename(path);

      final response = await _apiClient.multipartPost(
        '/audio/transcribe-oracle',
        fileBytes: fileBytes,
        filename: filename,
        fields: {
          'language': language,
          'model_type': 'WHISPER_LARGE_V3T',
        },
      );

      // Handle ApiClient's payload wrapping if present
      final data = response.containsKey('payload') ? response['payload'] : response;
      final jobId = data['job_id'] as String;
      
      _updateState(SpeechTranscriptionState.processing);

      // Start polling
      return await _pollForCompletion(jobId);
    } catch (e) {
      debugPrint('Error during transcription flow: $e');
      _updateState(SpeechTranscriptionState.error);
      rethrow;
    }
  }

  Future<String> _pollForCompletion(String jobId) async {
    final completer = Completer<String>();
    int attempts = 0;
    const maxAttempts = 100; // ~5 minutes with 3s interval

    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      attempts++;
      if (attempts >= maxAttempts) {
        timer.cancel();
        _updateState(SpeechTranscriptionState.error);
        completer.completeError('Transcription timed out');
        return;
      }

      try {
        final response = await _apiClient.get('/audio/transcription-status/$jobId');
        final status = response['job_status'] as String;

        if (status == 'succeeded') {
          timer.cancel();
          _updateState(SpeechTranscriptionState.done);
          completer.complete(response['transcript'] as String);
        } else if (status == 'failed') {
          timer.cancel();
          _updateState(SpeechTranscriptionState.error);
          completer.completeError('Transcription failed on backend');
        }
      } catch (e) {
        debugPrint('Polling error: $e');
        // We continue polling unless it's a fatal error
      }
    });

    return completer.future;
  }

  Future<void> cancel() async {
    await _recorder.stop();
    _pollingTimer?.cancel();
    _updateState(SpeechTranscriptionState.idle);
  }

  Future<double> getAmplitude() async {
    final amp = await _recorder.getAmplitude();
    return amp.current;
  }

  void dispose() {
    _pollingTimer?.cancel();
    _recorder.dispose();
  }
}
