import 'dart:async';
import 'dart:typed_data';
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
        encoder: AudioEncoder.aacLc, 
        sampleRate: 16000,
        numChannels: 1,
      ),
    );

    _recordSubscription = stream.listen(
      (data) {
        _audioStreamController?.add(data);
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
    await _audioRecorder.stop();
    await _recordSubscription?.cancel();
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
