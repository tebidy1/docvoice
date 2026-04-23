import 'package:universal_io/io.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';

class AudioRecordingService {
  AudioRecorder? _audioRecorder;
  String? _currentPath;

  Future<bool> hasPermission() async {
    if (kIsWeb) return true; // Force prompt via start() on Web
    
    _audioRecorder ??= AudioRecorder();
    // Check permission using permission_handler for broader compatibility
    if (!kIsWeb) {
      var status = await Permission.microphone.status;
      if (status.isDenied) {
        status = await Permission.microphone.request();
      }
      return status.isGranted;
    } else {
      // On Web, use the recorder's built-in check which triggers the prompt
      return await _audioRecorder!.hasPermission();
    }

  }

  Future<void> startRecording() async {
    _audioRecorder ??= AudioRecorder();
    try {
      if (await hasPermission()) {
        String? path;
        
        if (!kIsWeb) {
          final Directory appDocDir = await getApplicationDocumentsDirectory();
          final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
          // Use wav for Whisper compatibility (required: 16kHz Mono WAV)
          path = '${appDocDir.path}/recording_$timestamp.wav';
          _currentPath = path;
        } else {
           // On Web, use a meaningful filename — the record_web package
           // may fail to return a blob URL if the path is empty.
           path = 'recording_${DateTime.now().millisecondsSinceEpoch}.webm';
           _currentPath = path; 
        }

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
        await _audioRecorder!.start(config, path: path);
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

  Future<String?> stopRecording() async {
    try {
      if (_audioRecorder == null) {
        debugPrint("⚠️ stopRecording: _audioRecorder is null");
        return null;
      }
      final isActive = await _audioRecorder!.isRecording();
      debugPrint("stopRecording: isRecording=$isActive");
      
      final path = await _audioRecorder!.stop();
      debugPrint("Stopped recording. Saved to: $path (type: ${path.runtimeType})");
      
      // On web, if stop() returns null or empty but we have a stored path
      if ((path == null || path.isEmpty) && _currentPath != null) {
        debugPrint("⚠️ stop() returned null/empty. _currentPath was: $_currentPath");
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
     return _audioRecorder!.onAmplitudeChanged(const Duration(milliseconds: 100)); // Update every 100ms
  }
}


