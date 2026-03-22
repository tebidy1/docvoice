/// ============================================================
/// AudioChunkerService — Dynamic VAD-based Audio Chunking
/// ============================================================
/// Captures continuous 16kHz PCM audio and detects silence
/// using Voice Activity Detection (VAD). Flushes audio chunks
/// to a callback when silence is detected.
///
/// Context continuity is maintained by passing previous
/// transcription text as `initial_prompt` to the next chunk.
/// ============================================================

import 'dart:async';
import 'dart:typed_data';

import 'whisper_isolate_service.dart';

/// Callback type for when a chunk is transcribed.
typedef OnChunkTranscribed = void Function(String text);

/// Callback type for when an error occurs.
typedef OnChunkError = void Function(String error);

class AudioChunkerService {
  final WhisperIsolateService _whisperService;
  final OnChunkTranscribed onChunkTranscribed;
  final OnChunkError? onError;

  // VAD configuration
  static const int _sampleRate = 16000;
  static const double _silenceThresholdRms = 0.01;
  static const int _silenceDurationMs = 1000;
  static const int _minChunkDurationMs = 1500;
  static const int _maxChunkDurationMs = 30000;

  // Internal state
  final List<double> _audioBuffer = [];
  int _silenceSampleCount = 0;
  int _totalSampleCount = 0;
  String _previousTranscript = '';
  bool _isActive = false;

  // Track the currently running transcription future
  Completer<void>? _activeTranscription;

  // Accumulated full transcript
  final StringBuffer _fullTranscript = StringBuffer();

  AudioChunkerService({
    required WhisperIsolateService whisperService,
    required this.onChunkTranscribed,
    this.onError,
  }) : _whisperService = whisperService;

  /// Returns the full accumulated transcript.
  String get fullTranscript => _fullTranscript.toString();

  /// Whether the chunker is actively processing.
  bool get isActive => _isActive;

  /// Start accepting audio data.
  void start() {
    _audioBuffer.clear();
    _silenceSampleCount = 0;
    _totalSampleCount = 0;
    _previousTranscript = '';
    _fullTranscript.clear();
    _activeTranscription = null;
    _isActive = true;
    print('[AudioChunker] Started');
  }

  /// Feed raw PCM16 bytes (int16, mono, 16kHz) from the microphone.
  void feedPcm16(Uint8List pcm16Bytes) {
    if (!_isActive) return;

    // Convert int16 to float32
    final floatSamples = pcm16ToFloat32(pcm16Bytes);
    _audioBuffer.addAll(floatSamples);
    _totalSampleCount += floatSamples.length;

    // Calculate RMS for this chunk
    double sumSquares = 0.0;
    for (final sample in floatSamples) {
      sumSquares += sample * sample;
    }
    final rms = floatSamples.isNotEmpty
        ? (sumSquares / floatSamples.length)
        : 0.0;
    final isSilence = rms < (_silenceThresholdRms * _silenceThresholdRms);

    if (isSilence) {
      _silenceSampleCount += floatSamples.length;
    } else {
      _silenceSampleCount = 0;
    }

    final totalDurationMs = (_totalSampleCount * 1000) ~/ _sampleRate;
    final silenceDurationMs = (_silenceSampleCount * 1000) ~/ _sampleRate;

    // Flush conditions:
    // 1. Enough audio AND silence detected
    // 2. OR max chunk duration reached
    // Only flush if no transcription is currently running
    if (_activeTranscription == null &&
        ((totalDurationMs >= _minChunkDurationMs && silenceDurationMs >= _silenceDurationMs) ||
         totalDurationMs >= _maxChunkDurationMs)) {
      _flushBuffer();
    }
  }

  /// Flush any remaining audio in the buffer (called when recording stops).
  Future<void> flush() async {
    print('[AudioChunker] flush() called. Active transcription: ${_activeTranscription != null}, buffer: ${_audioBuffer.length} samples');
    
    // 1. Wait for any ongoing transcription to finish
    if (_activeTranscription != null) {
      print('[AudioChunker] Waiting for active transcription to complete...');
      await _activeTranscription!.future.timeout(
        const Duration(seconds: 120),
        onTimeout: () {
          print('[AudioChunker] WARNING: Transcription timed out after 120s');
        },
      );
      print('[AudioChunker] Active transcription completed.');
    }
    
    // 2. Now flush any remaining audio
    if (_audioBuffer.isNotEmpty) {
      print('[AudioChunker] Flushing remaining ${_audioBuffer.length} samples...');
      await _processChunk();
    }
    
    _isActive = false;
    print('[AudioChunker] Stopped. Final transcript length: ${_fullTranscript.length}');
  }

  /// Snapshot the buffer and process it as a single chunk.
  void _flushBuffer() {
    if (_activeTranscription != null || _audioBuffer.isEmpty) return;
    
    // Fire-and-forget — but track the future via Completer
    _processChunk();
  }

  /// Process the current buffer contents. Returns when transcription is done.
  Future<void> _processChunk() async {
    if (_audioBuffer.isEmpty) return;
    
    final completer = Completer<void>();
    _activeTranscription = completer;

    // Snapshot current buffer
    final chunkSamples = List<double>.from(_audioBuffer);
    _audioBuffer.clear();
    _silenceSampleCount = 0;
    _totalSampleCount = 0;

    final chunkDurationMs = (chunkSamples.length * 1000) ~/ _sampleRate;
    print('[AudioChunker] Processing chunk: ${chunkDurationMs}ms, ${chunkSamples.length} samples');

    try {
      final text = await _whisperService.transcribe(
        chunkSamples,
        language: 'en',
        prompt: _previousTranscript,
      );

      if (text.trim().isNotEmpty) {
        _previousTranscript = text.trim();
        _fullTranscript.write(text);
        onChunkTranscribed(text);
        print('[AudioChunker] Chunk transcribed: "${text.substring(0, text.length > 50 ? 50 : text.length)}..."');
      } else {
        print('[AudioChunker] Chunk transcribed but empty result');
      }
    } catch (e) {
      print('[AudioChunker] Transcription error: $e');
      onError?.call(e.toString());
    } finally {
      _activeTranscription = null;
      completer.complete();
    }
  }

  /// Stop and clean up.
  void dispose() {
    _isActive = false;
    _audioBuffer.clear();
    _activeTranscription = null;
    print('[AudioChunker] Disposed');
  }
}
