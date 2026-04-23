import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;
import 'model_download_service.dart';

/// Offline STT engine using sherpa_onnx + Whisper-Small.en (ONNX INT8).
/// English-only, with DSP pre-processing, Silero VAD, and Medical Hotwords.
class SherpaLocalService {
  static final SherpaLocalService _instance = SherpaLocalService._internal();
  factory SherpaLocalService() => _instance;
  SherpaLocalService._internal();

  sherpa.OfflineRecognizer? _recognizer;
  sherpa.VoiceActivityDetector? _vad;
  bool _isInitialized = false;
  String? _modelDir;
  String? _vadModelPath;
  String? _hotwordsPath;
  String? _lastError; // Store last initialization error for debugging

  // DSP Configuration
  static const double _noiseGateThreshold = 0.005; // Lowered: 0.01 was cutting soft consonants
  static const double _targetPeak = 0.95;

  // Segment merging: merge VAD segments closer than this gap (seconds)
  static const double _mergeGapSeconds = 1.0;

  /// Check if the Whisper model has been downloaded.
  Future<bool> isModelReady() => ModelDownloadService().isModelReady();

  /// Initialize the Whisper-Small.en ONNX recognizer.
  /// Model files must have been downloaded by ModelDownloadService first.
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // --- Resolve paths ---
      final downloadService = ModelDownloadService();
      _modelDir = await downloadService.modelDir;

      // Check model exists
      if (!await downloadService.isModelReady()) {
        print("❌ Model files not found. Please download first.");
        return;
      }

      // VAD model (bundled in assets, copy to filesystem)
      final appDir = await getApplicationDocumentsDirectory();
      _vadModelPath = '${appDir.path}/silero_vad.onnx';
      await _copyAssetIfNeeded(
        'assets/core/entities/silero_vad.onnx',
        _vadModelPath!,
      );

      // Medical Hotwords (bundled in assets, copy to filesystem)
      _hotwordsPath = '${appDir.path}/medical_hotwords.txt';
      await _copyAssetIfNeeded(
        'assets/hotwords/medical_hotwords.txt',
        _hotwordsPath!,
      );

      // --- Initialize sherpa-onnx bindings ---
      sherpa.initBindings();

      // --- Create OfflineRecognizer with Whisper-Small.en config ---
      print("⚙️ Creating OfflineRecognizer...");
      print("   Encoder: ${_modelDir!}/small.en-encoder.int8.onnx");
      print("   Decoder: ${_modelDir!}/small.en-decoder.int8.onnx");
      print("   Tokens:  ${_modelDir!}/small.en-tokens.txt");
      
      final config = sherpa.OfflineRecognizerConfig(
        model: sherpa.OfflineModelConfig(
          whisper: sherpa.OfflineWhisperModelConfig(
            encoder: '${_modelDir!}/small.en-encoder.int8.onnx',
            decoder: '${_modelDir!}/small.en-decoder.int8.onnx',
            language: 'en',
            task: 'transcribe',
            tailPaddings: 200, // Pad end to prevent last-word cutoff
          ),
          tokens: '${_modelDir!}/small.en-tokens.txt',
          numThreads: 4,
          debug: false,
          provider: 'cpu',
        ),
        // Note: hotwordsFile disabled for Whisper (attention-based decoder
        // may not support CTC-style hotwords biasing)
        // hotwordsFile: _hotwordsPath!,
        // hotwordsScore: 1.5,
        blankPenalty: 0.0,
      );

      _recognizer = sherpa.OfflineRecognizer(config);

      // --- Create VoiceActivityDetector (Silero VAD) ---
      final vadConfig = sherpa.VadModelConfig(
        sileroVad: sherpa.SileroVadModelConfig(
          model: _vadModelPath!,
          threshold: 0.5,
          minSilenceDuration: 0.8,  // Was 0.5: raised to avoid splitting mid-sentence
          minSpeechDuration: 1.5,   // Was 0.25: raised so Whisper gets full phrases, not fragments
          windowSize: 512,
        ),
        sampleRate: 16000,
        numThreads: 1,
        debug: false,
      );

      _vad = sherpa.VoiceActivityDetector(
        config: vadConfig,
        bufferSizeInSeconds: 60.0,
      );

      _isInitialized = true;
      _lastError = null;
      print("✅ Sherpa (Whisper-Small.en) + VAD initialized.");
    } catch (e, stackTrace) {
      print("❌ Error initializing Sherpa Local Service: $e");
      print("   Stack trace: $stackTrace");
      _lastError = e.toString();
      _isInitialized = false;
    }
  }

  /// Copy an asset file to the filesystem if it doesn't already exist.
  Future<void> _copyAssetIfNeeded(String assetPath, String destPath) async {
    final file = File(destPath);
    if (await file.exists()) return;

    print("📦 Copying: $assetPath → $destPath");
    final byteData = await rootBundle.load(assetPath);
    final buffer = byteData.buffer;
    await file.writeAsBytes(
      buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes),
      flush: true,
    );
  }

  /// Transcribes a WAV audio file and returns the raw text.
  /// The file must be 16kHz Mono WAV format.
  Future<String> transcribeAudioFile(String audioFilePath) async {
    if (!_isInitialized || _recognizer == null) {
      print("⚙️ Sherpa not initialized, initializing now...");
      await initialize();
    }

    if (_recognizer == null) {
      final errorDetail = _lastError ?? 'Unknown error';
      return 'Error: Engine init failed: $errorDetail';
    }

    try {
      // Read WAV
      final waveData = sherpa.readWave(audioFilePath);
      if (waveData.samples.isEmpty) {
        return 'Error: Audio file is empty.';
      }

      // --- DSP: Noise Gate + Normalization ---
      print("🎛️ DSP started (${waveData.samples.length} samples)...");
      final cleanedSamples = _processAudio(waveData.samples);

      // --- VAD: Extract speech-only segments ---
      _vad!.reset();
      final int windowSize = 512;
      int offset = 0;
      while (offset + windowSize <= cleanedSamples.length) {
        final chunk = Float32List.sublistView(
            cleanedSamples, offset, offset + windowSize);
        _vad!.acceptWaveform(chunk);
        offset += windowSize;
      }
      _vad!.flush();

      // --- Collect all VAD segments ---
      final List<Float32List> rawSegments = [];
      while (!_vad!.isEmpty()) {
        final segment = _vad!.front();
        if (segment.samples.isNotEmpty) {
          rawSegments.add(Float32List.fromList(segment.samples));
        }
        _vad!.pop();
      }

      print("📊 VAD found ${rawSegments.length} raw segments.");

      // --- Merge adjacent segments for better Whisper context ---
      // Whisper needs full sentences, not isolated words.
      // We merge all segments into one big buffer so the attention
      // mechanism can use cross-word context for better accuracy.
      final List<Float32List> mergedSegments = _mergeSegments(rawSegments, waveData.sampleRate);
      print("📊 Merged into ${mergedSegments.length} chunks for Whisper.");

      final StringBuffer fullTranscription = StringBuffer();

      for (int i = 0; i < mergedSegments.length; i++) {
        final seg = mergedSegments[i];
        final durationSec = (seg.length / 16000.0).toStringAsFixed(2);
        print("🔊 Chunk #${i + 1}: ${durationSec}s (${seg.length} samples)");

        final stream = _recognizer!.createStream();
        stream.acceptWaveform(
          samples: seg,
          sampleRate: waveData.sampleRate,
        );
        _recognizer!.decode(stream);
        final result = _recognizer!.getResult(stream);
        stream.free();

        final text = _cleanOutput(result.text);
        if (text.isNotEmpty) {
          print("🎙️ Chunk #${i + 1}: $text");
          if (fullTranscription.isNotEmpty) fullTranscription.write(" ");
          fullTranscription.write(text);
        }
      }

      // Fallback: if VAD found nothing, try direct recognition
      if (mergedSegments.isEmpty || fullTranscription.isEmpty) {
        print("⚠️ VAD empty. Falling back to direct recognition...");
        final stream = _recognizer!.createStream();
        stream.acceptWaveform(
          samples: cleanedSamples,
          sampleRate: waveData.sampleRate,
        );
        _recognizer!.decode(stream);
        final result = _recognizer!.getResult(stream);
        stream.free();
        final text = _cleanOutput(result.text);
        if (text.isNotEmpty) return text;
        return 'Error: No speech detected.';
      }

      return fullTranscription.toString().trim();
    } catch (e) {
      print("❌ Transcription error: $e");
      return 'Error: Transcription failed. $e';
    }
  }

  /// Clean up resources.
  void dispose() {
    _recognizer?.free();
    _vad?.free();
    _recognizer = null;
    _vad = null;
    _isInitialized = false;
  }

  // ───────────────────────────────────────────
  // DSP: Noise Gate + Normalization
  // ───────────────────────────────────────────
  Float32List _processAudio(Float32List originalSamples) {
    if (originalSamples.isEmpty) return originalSamples;

    final processed = Float32List(originalSamples.length);
    double maxAmplitude = 0.0;

    // 1. Noise Gate & find max
    for (int i = 0; i < originalSamples.length; i++) {
      double sample = originalSamples[i];
      if (sample.abs() < _noiseGateThreshold) {
        processed[i] = 0.0;
      } else {
        processed[i] = sample;
        if (sample.abs() > maxAmplitude) {
          maxAmplitude = sample.abs();
        }
      }
    }

    // 2. Normalization
    if (maxAmplitude == 0.0 || maxAmplitude >= 1.0) return processed;
    final double gain = _targetPeak / maxAmplitude;
    if (gain > 1.0) {
      for (int i = 0; i < processed.length; i++) {
        processed[i] = (processed[i] * gain).clamp(-1.0, 1.0);
      }
    }
    return processed;
  }

  // ───────────────────────────────────────────
  // Merge adjacent VAD segments into longer chunks
  // so Whisper gets full-sentence context.
  // Whisper can handle up to 30s per chunk.
  // ───────────────────────────────────────────
  List<Float32List> _mergeSegments(List<Float32List> segments, int sampleRate) {
    if (segments.isEmpty) return [];
    if (segments.length == 1) return segments;

    final int maxChunkSamples = 30 * sampleRate; // 30 seconds max per Whisper window
    final int gapSamples = (_mergeGapSeconds * sampleRate).toInt();
    final Float32List silence = Float32List(gapSamples); // zero-filled gap

    final List<Float32List> merged = [];
    List<Float32List> currentParts = [segments[0]];
    int currentLength = segments[0].length;

    for (int i = 1; i < segments.length; i++) {
      final nextLen = segments[i].length + gapSamples;
      if (currentLength + nextLen <= maxChunkSamples) {
        // Merge: add a small silence gap then the next segment
        currentParts.add(silence);
        currentParts.add(segments[i]);
        currentLength += nextLen;
      } else {
        // Flush current merged chunk
        merged.add(_concatFloat32Lists(currentParts));
        currentParts = [segments[i]];
        currentLength = segments[i].length;
      }
    }
    // Flush last chunk
    merged.add(_concatFloat32Lists(currentParts));
    return merged;
  }

  Float32List _concatFloat32Lists(List<Float32List> lists) {
    int totalLen = 0;
    for (final l in lists) totalLen += l.length;
    final result = Float32List(totalLen);
    int offset = 0;
    for (final l in lists) {
      result.setRange(offset, offset + l.length, l);
      offset += l.length;
    }
    return result;
  }

  // ───────────────────────────────────────────
  // Output Cleaning (strip Whisper artifacts)
  // ───────────────────────────────────────────
  static final RegExp _specialTokenRegex = RegExp(r'<\|[^>]*\|>');
  static final RegExp _blankAudioRegex =
      RegExp(r'\[BLANK_AUDIO\]', caseSensitive: false);

  String _cleanOutput(String rawText) {
    String cleaned = rawText;
    cleaned = cleaned.replaceAll(_specialTokenRegex, '');
    cleaned = cleaned.replaceAll(_blankAudioRegex, '');
    cleaned = cleaned.replaceAll(RegExp(r'[<>|]'), '');
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ');
    return cleaned.trim();
  }
}


