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
          // Use m4a for AAC encoding (efficient and widely supported)
          path = '${appDocDir.path}/recording_$timestamp.m4a';
          _currentPath = path;
        } else {
           // On Web, path is ignored or handled internally by browser/recorder
           _currentPath = null; 
        }

        // Configure recording parameters
        RecordConfig config;
        
        if (kIsWeb) {
           // On Web/PWA, we MUST use Opus (or allow browser default, but explicit Opus is safer)
           config = const RecordConfig(
             encoder: AudioEncoder.opus,
           ); 
        } else {
           // WAV/AAC is safer for Mobile/Desktop
           config = const RecordConfig(
            encoder: AudioEncoder.aacLc, 
            sampleRate: 44100, 
            bitRate: 128000,
          );
        }

        // Start recording to file
        if (path != null) {
          await _audioRecorder!.start(config, path: path);
          debugPrint("Started recording to: $path");
        } else {
           // Web stream / blob
           await _audioRecorder!.start(config, path: ''); 
           debugPrint("Started recording (Web)");
        }
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
      if (_audioRecorder == null) return null;
      final path = await _audioRecorder!.stop();
      debugPrint("Stopped recording. Saved to: $path");
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

  // Reactive UI Support
  Stream<Amplitude> get onAmplitudeChanged {
     _audioRecorder ??= AudioRecorder();
     return _audioRecorder!.onAmplitudeChanged(const Duration(milliseconds: 100)); // Update every 100ms
  }
}
