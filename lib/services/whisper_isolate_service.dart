/// ============================================================
/// WhisperIsolateService — Background Isolate for whisper.cpp
/// ============================================================
/// Runs whisper model loading and transcription in a separate
/// Isolate to avoid blocking the UI thread.
///
/// Lifecycle:
///   1. Call [initialize()] — loads model into RAM in background
///   2. Call [transcribe()] — sends PCM chunks for transcription
///   3. Call [dispose()] — frees model and shuts down isolate
/// ============================================================

import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'whisper_bridge_ffi.dart';

/// Message types for Isolate communication
enum _IsolateCommand {
  init,
  transcribe,
  dispose,
}

/// Message sent to the background Isolate
class _IsolateRequest {
  final _IsolateCommand command;
  final dynamic data;
  final SendPort replyPort;

  _IsolateRequest({
    required this.command,
    this.data,
    required this.replyPort,
  });
}

/// Response from the background Isolate
class _IsolateResponse {
  final bool success;
  final dynamic data;
  final String? error;

  _IsolateResponse({required this.success, this.data, this.error});
}

/// Transcription request data
class TranscribeRequest {
  final List<double> pcmFloat32;
  final String language;
  final String prompt;

  TranscribeRequest({
    required this.pcmFloat32,
    this.language = 'en',
    this.prompt = '',
  });
}

class WhisperIsolateService {
  Isolate? _isolate;
  SendPort? _sendPort;
  bool _isInitialized = false;
  bool _isModelLoaded = false;

  bool get isInitialized => _isInitialized;
  bool get isModelLoaded => _isModelLoaded;

  /// Initializes the background Isolate and loads the model.
  /// [modelPath] must be the absolute path to the .bin model file.
  /// Throws on failure.
  Future<void> initialize(String modelPath) async {
    if (_isInitialized) return;

    final receivePort = ReceivePort();
    _isolate = await Isolate.spawn(
      _isolateEntry,
      receivePort.sendPort,
    );

    // Get the send port from the Isolate
    final completer = Completer<SendPort>();
    final sub = receivePort.listen((message) {
      if (message is SendPort) {
        completer.complete(message);
      }
    });
    _sendPort = await completer.future;
    sub.cancel();
    receivePort.close();
    _isInitialized = true;

    // Load the model
    final result = await _sendCommand(_IsolateCommand.init, modelPath);
    if (!result.success) {
      throw Exception('Failed to load whisper model: ${result.error}');
    }
    _isModelLoaded = true;
    print('[WhisperIsolate] Model loaded successfully');
  }

  /// Transcribes PCM float32 audio data.
  /// Returns the transcribed text.
  Future<String> transcribe(
    List<double> pcmFloat32, {
    String language = 'en',
    String prompt = '',
  }) async {
    if (!_isModelLoaded) {
      throw Exception('Whisper model not loaded. Call initialize() first.');
    }

    final request = TranscribeRequest(
      pcmFloat32: pcmFloat32,
      language: language,
      prompt: prompt,
    );

    final result = await _sendCommand(_IsolateCommand.transcribe, request);
    if (!result.success) {
      throw Exception('Transcription failed: ${result.error}');
    }

    return result.data as String? ?? '';
  }

  /// Frees the model and shuts down the background Isolate.
  Future<void> dispose() async {
    if (!_isInitialized) return;

    try {
      await _sendCommand(_IsolateCommand.dispose, null);
    } catch (_) {
      // Ignore errors during cleanup
    }

    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _sendPort = null;
    _isInitialized = false;
    _isModelLoaded = false;
    print('[WhisperIsolate] Disposed');
  }

  /// Sends a command to the Isolate and waits for a response.
  Future<_IsolateResponse> _sendCommand(_IsolateCommand command, dynamic data) {
    final completer = Completer<_IsolateResponse>();
    final replyPort = ReceivePort();

    replyPort.listen((message) {
      if (message is _IsolateResponse) {
        completer.complete(message);
        replyPort.close();
      }
    });

    _sendPort!.send(_IsolateRequest(
      command: command,
      data: data,
      replyPort: replyPort.sendPort,
    ));

    return completer.future;
  }

  /// The entry point for the background Isolate.
  static void _isolateEntry(SendPort mainSendPort) {
    final receivePort = ReceivePort();
    mainSendPort.send(receivePort.sendPort);

    WhisperBridgeFFI? bridge;

    receivePort.listen((message) {
      if (message is _IsolateRequest) {
        switch (message.command) {
          case _IsolateCommand.init:
            try {
              bridge = WhisperBridgeFFI();
              final modelPath = message.data as String;
              final success = bridge!.init(modelPath);
              message.replyPort.send(_IsolateResponse(
                success: success,
                error: success ? null : 'whisper_bridge_init returned 0',
              ));
            } catch (e) {
              message.replyPort.send(_IsolateResponse(
                success: false,
                error: e.toString(),
              ));
            }
            break;

          case _IsolateCommand.transcribe:
            try {
              if (bridge == null || !bridge!.isLoaded()) {
                print('[WhisperIsolate] ERROR: Model not loaded for transcription');
                message.replyPort.send(_IsolateResponse(
                  success: false,
                  error: 'Model not loaded',
                ));
                return;
              }

              final request = message.data as TranscribeRequest;
              print('[WhisperIsolate] Starting transcription of ${request.pcmFloat32.length} samples...');
              final stopwatch = Stopwatch()..start();
              
              final text = bridge!.transcribe(
                request.pcmFloat32,
                language: request.language,
                prompt: request.prompt,
              );
              
              stopwatch.stop();
              print('[WhisperIsolate] Transcription completed in ${stopwatch.elapsedMilliseconds}ms. Result: ${text.length} chars');

              message.replyPort.send(_IsolateResponse(
                success: true,
                data: text,
              ));
            } catch (e) {
              print('[WhisperIsolate] Transcription error: $e');
              message.replyPort.send(_IsolateResponse(
                success: false,
                error: e.toString(),
              ));
            }
            break;

          case _IsolateCommand.dispose:
            try {
              bridge?.free();
              bridge = null;
              message.replyPort.send(_IsolateResponse(success: true));
            } catch (e) {
              message.replyPort.send(_IsolateResponse(
                success: false,
                error: e.toString(),
              ));
            }
            break;
        }
      }
    });
  }
}

/// Utility to convert raw PCM16 bytes (int16) to float32 array.
/// Whisper expects float32 values in range [-1.0, 1.0].
List<double> pcm16ToFloat32(Uint8List pcm16Bytes) {
  // Ensure alignment for Int16List.view
  Uint8List alignedBytes = pcm16Bytes;
  if (pcm16Bytes.offsetInBytes % 2 != 0) {
    alignedBytes = Uint8List.fromList(pcm16Bytes);
  }
  final int16View = Int16List.view(alignedBytes.buffer, alignedBytes.offsetInBytes, alignedBytes.lengthInBytes ~/ 2);
  final result = List<double>.filled(int16View.length, 0.0);
  for (int i = 0; i < int16View.length; i++) {
    result[i] = int16View[i] / 32768.0;
  }
  return result;
}
