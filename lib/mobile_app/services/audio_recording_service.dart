// Updated AudioRecordingService
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:universal_io/io.dart';
import 'audio_recording_helper_stub.dart'
    if (dart.library.js_interop) 'audio_recording_helper_web.dart';

class AudioRecordingService {
  AudioRecorder? _audioRecorder;
  String? _currentPath;

  Future<bool> hasPermission() async {
    if (kIsWeb) {
       try {
         final granted = await requestWebMicrophonePermission();
         return granted;
       } catch (e) {
         debugPrint("Web microphone permission denied/error: $e");
         return false;
       }
    }

    _audioRecorder ??= AudioRecorder();
    // Check permission using permission_handler for broader compatibility
    var status = await Permission.microphone.status;
    if (status.isDenied) {
      status = await Permission.microphone.request();
    }
    return status.isGranted;
  }

  Future<void> startRecording() async {
    _audioRecorder ??= AudioRecorder();
    try {
      if (await hasPermission()) {
        String path = '';

        if (!kIsWeb) {
          final Directory appDocDir = await getApplicationDocumentsDirectory();
          final String timestamp =
              DateTime.now().millisecondsSinceEpoch.toString();
          // Use wav for Whisper compatibility (required: 16kHz Mono WAV)
          path = '${appDocDir.path}/recording_$timestamp.wav';
        } else {
          // On web, an empty string tells the record package to use a blob/memory.
          path = '';
        }
        _currentPath = path;

        // Configure recording parameters
        RecordConfig config;

        if (kIsWeb) {
          // On Web/PWA, use Opus encoding (widely supported in browsers)
          config = const RecordConfig(
            encoder: AudioEncoder.opus,
          );
        } else {
          // WAV 16kHz Mono is required for local Whisper
          config = const RecordConfig(
            encoder: AudioEncoder.wav,
            sampleRate: 16000,
            numChannels: 1, // Mono
          );
        }

        // Start recording
        await _audioRecorder!.start(config, path: path); // VERIFIED_FIX
        debugPrint("Started recording to: $path (isWeb: $kIsWeb)");
      } else {
        debugPrint("Microphone permission denied");
        throw Exception("Microphone permission denied");
      }
    } catch (e) {
      debugPrint("Error starting recording: $e");
      rethrow;
    }
  }

  Future<void> startRecordingCompressed() async {
    _audioRecorder ??= AudioRecorder();
    if (!await hasPermission()) {
      throw Exception("Microphone permission denied");
    }

    String path = '';

    if (kIsWeb) {
      // On web, blob mode — path stays empty
      _currentPath = '';
      // Try Opus first (best compression), fallback to browser default
      try {
        const config = RecordConfig(encoder: AudioEncoder.opus);
        await _audioRecorder!.start(config, path: '');
        debugPrint("✅ Web compressed recording started: Opus/WebM");
      } catch (e) {
        debugPrint("⚠️ Opus encoder failed on web: $e. Using browser default.");
        await _audioRecorder!.start(const RecordConfig(), path: '');
        debugPrint("✅ Web recording started with browser-default encoder");
      }
    } else {
      // Native (Android/iOS): prefer AAC → M4A
      final Directory appDocDir = await getApplicationDocumentsDirectory();
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      path = '${appDocDir.path}/recording_$timestamp.m4a';
      _currentPath = path;

      try {
        const config = RecordConfig(
          encoder: AudioEncoder.aacLc,
          sampleRate: 16000,
          numChannels: 1,
        );
        await _audioRecorder!.start(config, path: path);
        debugPrint("✅ Native compressed recording started: AAC/M4A → $path");
      } catch (e) {
        // 🛡️ Fallback to WAV if AAC is not supported on this device
        debugPrint("⚠️ AAC encoder failed: $e. Falling back to WAV.");
        final wavPath = path.replaceAll('.m4a', '.wav');
        _currentPath = wavPath;
        await _audioRecorder!.start(
          const RecordConfig(
            encoder: AudioEncoder.wav,
            sampleRate: 16000,
            numChannels: 1,
          ),
          path: wavPath,
        );
        debugPrint("✅ WAV fallback recording started → $wavPath");
      }
    }
  }


  Future<String?> stopRecording() async {
    try {
      if (_audioRecorder == null) {
        debugPrint("⚠️ stopRecording: _audioRecorder is null");
        return null;
      }
      final isActive = await _audioRecorder!.isRecording();
      debugPrint("stopRecording: isRecording=$isActive");

      final path = await _audioRecorder!.stop();
      debugPrint(
          "Stopped recording. Saved to: $path (type: ${path.runtimeType})");

      // On web, if stop() returns null or empty but we have a stored path
      if ((path == null || path.isEmpty) && _currentPath != null) {
        debugPrint(
            "⚠️ stop() returned null/empty. _currentPath was: $_currentPath");
      }

      return path;
    } catch (e) {
      debugPrint("Error stopping recording: $e");
      return null;
    }
  }

  Future<void> cancelRecording() async {
    if (_audioRecorder != null) await _audioRecorder!.cancel();
    if (_currentPath != null && !kIsWeb) {
      final file = File(_currentPath!);
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  Future<void> dispose() async {
    if (_audioRecorder != null) await _audioRecorder!.dispose();
  }

  Future<bool> isRecording() async {
    if (_audioRecorder == null) return false;
    return await _audioRecorder!.isRecording();
  }

  Future<Amplitude> getAmplitude() async {
    if (_audioRecorder == null) return Amplitude(current: -160.0, max: -160.0);
    return await _audioRecorder!.getAmplitude();
  }

  // Reactive UI Support
  Stream<Amplitude> get onAmplitudeChanged {
    _audioRecorder ??= AudioRecorder();
    return _audioRecorder!.onAmplitudeChanged(
        const Duration(milliseconds: 100)); // Update every 100ms
  }
}
