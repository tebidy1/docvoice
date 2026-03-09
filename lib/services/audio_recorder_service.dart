import 'dart:async';
import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:record/record.dart';

class AudioRecorderService {
  final AudioRecorder _audioRecorder = AudioRecorder();
  StreamController<Uint8List>? _audioStreamController;
  StreamSubscription? _recordSubscription;

  Future<bool> hasPermission() async {
    return await _audioRecorder.hasPermission();
  }

  Future<List<InputDevice>> listInputDevices() async {
    return await _audioRecorder.listInputDevices();
  }

  Future<Amplitude> getAmplitude() async {
    return await _audioRecorder.getAmplitude();
  }

  Future<Stream<Uint8List>> startRecording() async {
    if (!await hasPermission()) {
      throw Exception("Microphone permission denied");
    }

    _audioStreamController = StreamController<Uint8List>();

    // Start recording to stream
    // We use PCM 16-bit for raw data or Opus if supported by the container.
    // For streaming to Whisper, raw PCM or WAV is often easiest to handle if we chunk it manually,
    // but Opus is better for network.
    // Groq Whisper supports: flac, mp3, mp4, mpeg, mpga, m4a, ogg, wav, webm.
    // We will try to stream raw PCM and wrap it or just stream Opus packets if possible.
    // For simplicity in MVP, let's use raw PCM 16bit 16kHz (Whisper standard).

    final stream = await _audioRecorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
      ),
    );

    _recordSubscription = stream.listen(
      (data) {
        if (_audioStreamController != null &&
            !_audioStreamController!.isClosed) {
          _audioStreamController?.add(data);
        }
      },
      onError: (e) {
        print("Recording error: $e");
        _audioStreamController?.addError(e);
      },
      onDone: () {
        _audioStreamController?.close();
      },
    );

    return _audioStreamController!.stream;
  }

  Future<void> stopRecording() async {
    // ⚠️  Order matters!
    // 1. Stop the hardware recorder FIRST so it flushes any buffered PCM data
    //    into the stream before we close it.
    await _audioRecorder.stop();

    // 2. Cancel the subscription (no more incoming chunks).
    await _recordSubscription?.cancel();
    _recordSubscription = null;

    // 3. Now it is safe to close the StreamController – Oracle/Whisper has
    //    already received everything.
    await _audioStreamController?.close();
    _audioStreamController = null;
  }

  Future<void> startRecordingToFile(String path) async {
    if (!await hasPermission()) {
      throw Exception("Microphone permission denied");
    }

    await _audioRecorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: path,
    );
  }

  Future<void> startRecordingCompressed(String path) async {
    if (!await hasPermission()) {
      throw Exception("Microphone permission denied");
    }

    AudioEncoder encoder = AudioEncoder.aacLc;
    if (!kIsWeb && Platform.isWindows) {
      encoder = AudioEncoder.flac; // FLAC is the best compression on Windows
    }

    try {
      await _audioRecorder.start(
        RecordConfig(
          encoder: encoder,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: path,
      );
      print("✅ Compressed recording started: ${encoder.name} → $path");
    } catch (e) {
      // 🛡️ Robust Fallback: if compressed encoder fails, fall back to WAV silently
      print("⚠️ Compressed encoder '${encoder.name}' failed: $e. Falling back to WAV.");
      // Adjust path extension to .wav for fallback
      final wavPath = path.replaceAll(RegExp(r'\.(flac|m4a|aac|opus)$'), '.wav');
      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: wavPath,
      );
      print("✅ WAV fallback recording started → $wavPath");
    }
  }


  Future<String?> stop() async {
    await _recordSubscription?.cancel();
    await _audioStreamController?.close();
    _audioStreamController = null;
    return await _audioRecorder.stop();
  }

  void dispose() {
    _audioRecorder.dispose();
  }
}
