import 'dart:io';
import 'dart:ffi';
import 'package:ffi/ffi.dart';

// Native
typedef WhisperInitNative = Int32 Function(Pointer<Utf8>);
typedef WhisperInitDart = int Function(Pointer<Utf8>);

typedef WhisperTranscribeNative = Pointer<Utf8> Function(Pointer<Float>, Int32, Pointer<Utf8>, Pointer<Utf8>);
typedef WhisperTranscribeDart = Pointer<Utf8> Function(Pointer<Float>, int, Pointer<Utf8>, Pointer<Utf8>);

typedef WhisperFreeNative = Void Function();
typedef WhisperFreeDart = void Function();

void main() async {
  print('[Test] Starting whisper_bridge.dll test...');
  
  DynamicLibrary lib;
  try {
    lib = DynamicLibrary.open('build/windows/x64/runner/Debug/whisper_bridge.dll');
    print('[Test] DLL Loaded from Debug folder');
  } catch (e) {
    print('[Test] Failed to load DLL: $e');
    return;
  }

  final initFunc = lib.lookupFunction<WhisperInitNative, WhisperInitDart>('whisper_bridge_init');
  final transcribeFunc = lib.lookupFunction<WhisperTranscribeNative, WhisperTranscribeDart>('whisper_bridge_transcribe');
  final freeFunc = lib.lookupFunction<WhisperFreeNative, WhisperFreeDart>('whisper_bridge_free');
  
  final modelFile = File('assets/models/ggml-small.en-q5_1.bin');
  
  if (!modelFile.existsSync()) {
    print('[Test] ERROR: Model not found at: ${modelFile.path}');
    return;
  }
  
  print('[Test] Calling whisper_bridge_init...');
  final pathPtr = modelFile.path.toNativeUtf8();
  try {
    final result = initFunc(pathPtr);
    print('[Test] Init Result: $result (1 means success)');
    if (result != 1) {
      print('[Test] Init failed, exiting.');
      return;
    }
  } catch (e) {
    print('[Test] Dart caught error during init: $e');
    return;
  } finally {
    calloc.free(pathPtr);
  }
  
  print('[Test] Simulating transcription with 1 sec silence...');
  final sampleCount = 16000;
  final samplesPtr = calloc<Float>(sampleCount);
  for (int i = 0; i < sampleCount; i++) {
    samplesPtr[i] = 0.0;
  }
  
  final langPtr = 'en'.toNativeUtf8();
  final promptPtr = ''.toNativeUtf8();
  
  try {
    final resultPtr = transcribeFunc(samplesPtr, sampleCount, langPtr, promptPtr);
    final text = resultPtr.toDartString();
    print('[Test] Transcribe result: "$text"');
  } catch (e) {
    print('[Test] Dart caught error during transcribe: $e');
  } finally {
    calloc.free(samplesPtr);
    calloc.free(langPtr);
    calloc.free(promptPtr);
  }
  
  print('[Test] Calling whisper_bridge_free...');
  try {
    freeFunc();
    print('[Test] Free completed.');
  } catch (e) {
    print('[Test] Error during free: $e');
  }
  
  print('[Test] All done cleanly.');
}
