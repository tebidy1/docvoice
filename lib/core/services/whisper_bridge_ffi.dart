/// ============================================================
/// WhisperBridgeFFI — Dart FFI bindings for whisper_bridge.dll
/// ============================================================
/// Provides type-safe Dart functions to interact with the
/// native whisper bridge. Used inside a background Isolate.
/// ============================================================

import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

// ── Native function type definitions ──

// int whisper_bridge_init(const char* model_path)
typedef WhisperInitNative = Int32 Function(Pointer<Utf8> modelPath);
typedef WhisperInitDart = int Function(Pointer<Utf8> modelPath);

// const char* whisper_bridge_transcribe(const float* samples, int num_samples, const char* language, const char* prompt)
typedef WhisperTranscribeNative = Pointer<Utf8> Function(
  Pointer<Float> samples,
  Int32 numSamples,
  Pointer<Utf8> language,
  Pointer<Utf8> prompt,
);
typedef WhisperTranscribeDart = Pointer<Utf8> Function(
  Pointer<Float> samples,
  int numSamples,
  Pointer<Utf8> language,
  Pointer<Utf8> prompt,
);

// void whisper_bridge_free()
typedef WhisperFreeNative = Void Function();
typedef WhisperFreeDart = void Function();

// int whisper_bridge_is_loaded()
typedef WhisperIsLoadedNative = Int32 Function();
typedef WhisperIsLoadedDart = int Function();

/// Wrapper around the native whisper_bridge.dll functions.
class WhisperBridgeFFI {
  late final DynamicLibrary _lib;
  late final WhisperInitDart _init;
  late final WhisperTranscribeDart _transcribe;
  late final WhisperFreeDart _free;
  late final WhisperIsLoadedDart _isLoaded;

  bool _loaded = false;

  WhisperBridgeFFI() {
    _lib = _loadLibrary();
    _init = _lib
        .lookupFunction<WhisperInitNative, WhisperInitDart>('whisper_bridge_init');
    _transcribe = _lib
        .lookupFunction<WhisperTranscribeNative, WhisperTranscribeDart>('whisper_bridge_transcribe');
    _free = _lib
        .lookupFunction<WhisperFreeNative, WhisperFreeDart>('whisper_bridge_free');
    _isLoaded = _lib
        .lookupFunction<WhisperIsLoadedNative, WhisperIsLoadedDart>('whisper_bridge_is_loaded');
  }

  static DynamicLibrary _loadLibrary() {
    if (Platform.isWindows) {
      // Try loading from the same directory as the executable first
      try {
        return DynamicLibrary.open('whisper_bridge.dll');
      } catch (_) {
        // Try the executable directory explicitly
        final exeDir = File(Platform.resolvedExecutable).parent.path;
        return DynamicLibrary.open('$exeDir\\whisper_bridge.dll');
      }
    }
    throw UnsupportedError('WhisperBridge is only supported on Windows');
  }

  /// Loads the whisper model from the given file path.
  /// Returns true on success, false on failure.
  bool init(String modelPath) {
    final pathPtr = modelPath.toNativeUtf8();
    try {
      final result = _init(pathPtr);
      _loaded = result == 1;
      return _loaded;
    } finally {
      calloc.free(pathPtr);
    }
  }

  /// Transcribes raw 16kHz float32 PCM audio.
  /// Returns the transcription text (empty string on error).
  String transcribe(List<double> pcmFloat32, {String language = 'en', String prompt = ''}) {
    if (!_loaded) return '';

    // Allocate native float array
    final sampleCount = pcmFloat32.length;
    final samplesPtr = calloc<Float>(sampleCount);
    final languagePtr = language.toNativeUtf8();
    final promptPtr = prompt.toNativeUtf8();

    try {
      // Copy PCM data to native memory
      for (int i = 0; i < sampleCount; i++) {
        samplesPtr[i] = pcmFloat32[i];
      }

      final resultPtr = _transcribe(samplesPtr, sampleCount, languagePtr, promptPtr);
      return resultPtr.toDartString();
    } finally {
      calloc.free(samplesPtr);
      calloc.free(languagePtr);
      calloc.free(promptPtr);
    }
  }

  /// Frees the loaded model from memory.
  void free() {
    _free();
    _loaded = false;
  }

  /// Checks if the model is currently loaded.
  bool isLoaded() {
    return _isLoaded() == 1;
  }
}






