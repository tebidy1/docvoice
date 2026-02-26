import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:http/http.dart' as http;
import 'oci_request_signer.dart';

// ─────────────────────────────────────────────────────────────────────────────
// A/B Testing model selection enum
// ─────────────────────────────────────────────────────────────────────────────

enum OracleSTTModel {
  /// modelType = "ORACLE", domain = "MEDICAL"  (default)
  oracleMedical,

  /// modelType = "WHISPER", domain = "GENERIC"
  /// ⚠️  Several payload params are FORBIDDEN with this model — see _buildConfig().
  whisperGeneric,
}

// ─────────────────────────────────────────────────────────────────────────────
// Connection states
// ─────────────────────────────────────────────────────────────────────────────

enum OracleSpeechState {
  idle,
  authenticating,
  connecting,
  ready,      // WebSocket open, streaming audio
  finalizing, // Recording stopped, waiting for final result
  done,
  error,
}

// ─────────────────────────────────────────────────────────────────────────────
// OracleLiveSpeechService
// ─────────────────────────────────────────────────────────────────────────────

/// Handles real-time streaming transcription via Oracle OCI Speech (me-riyadh-1).
///
/// Usage:
/// ```dart
/// final service = OracleLiveSpeechService(
///   credentials: OciCredentials.fromEnv(),
///   model: OracleSTTModel.oracleMedical,
///   language: 'ar-SA',
/// );
///
/// await service.startSession(audioStream);   // pass the raw PCM stream
/// ...
/// final transcript = await service.stopSession();
/// ```
class OracleLiveSpeechService {
  // ── Credentials & config ──────────────────────────────────────────────────
  final OciCredentials credentials;
  final OracleSTTModel model;
  final String language; // e.g. 'ar-SA' or 'en-US'

  // ── Private state ─────────────────────────────────────────────────────────
  WebSocketChannel? _channel;
  StreamSubscription? _audioSubscription;
  StreamSubscription? _wsSubscription;
  OracleSpeechState _state = OracleSpeechState.idle;

  /// Accumulates all *final* transcription segments.
  final _finalSegments = <String>[];

  /// Completer resolved when the server confirms it has sent all final results.
  Completer<String>? _transcriptCompleter;

  // On-state-change callback (optional, useful for UI updates)
  void Function(OracleSpeechState)? onStateChange;

  // On-error callback
  void Function(Object)? onError;

  OracleLiveSpeechService({
    required this.credentials,
    this.model = OracleSTTModel.oracleMedical,
    this.language = 'ar-SA',
    this.onStateChange,
    this.onError,
  });

  // ── Region-derived endpoint ───────────────────────────────────────────────

  static const _region = 'me-riyadh-1';
  static const _httpsEndpoint =
      'https://speech.aiservice.$_region.oci.oraclecloud.com';
  static const _wssEndpoint =
      'wss://realtime.aiservice.$_region.oci.oraclecloud.com';

  // ═══════════════════════════════════════════════════════════════════════════
  // Public API
  // ═══════════════════════════════════════════════════════════════════════════

  OracleSpeechState get state => _state;

  /// Opens a real-time transcription session and begins forwarding audio chunks.
  ///
  /// [audioChunks] — raw PCM-16 16kHz Mono byte stream from the microphone.
  ///
  /// Returns a [Future<String>] that resolves to the full final transcript
  /// once [stopSession] is called and OCI acknowledges the final result.
  Future<String> startSession(Stream<Uint8List> audioChunks) async {
    if (_state != OracleSpeechState.idle) {
      await stopSession();
    }

    _finalSegments.clear();
    _transcriptCompleter = Completer<String>();

    try {
      // Step 1: Obtain a short-lived OCI session token via REST (signed request).
      _setState(OracleSpeechState.authenticating);
      final sessionToken = await _createRealtimeSessionToken();

      // Step 2: Open WebSocket with the token.
      _setState(OracleSpeechState.connecting);
      await _openWebSocket(sessionToken);

      // Step 3: Start streaming audio.
      _setState(OracleSpeechState.ready);
      _streamAudio(audioChunks);
    } catch (e) {
      _setState(OracleSpeechState.error);
      onError?.call(e);
      _transcriptCompleter?.completeError(e);
    }

    return _transcriptCompleter!.future;
  }

  /// Signals "end of audio" to the server and waits for the final transcript.
  Future<String> stopSession() async {
    if (_channel != null && _state == OracleSpeechState.ready) {
      _setState(OracleSpeechState.finalizing);
      // Cancel audio forwarding — the stream is done.
      await _audioSubscription?.cancel();
      _audioSubscription = null;

      // Send "end of audio" sentinel to OCI so it can flush partial results.
      try {
        _channel!.sink.add(jsonEncode({'event': 'STOP'}));
      } catch (_) {/* WebSocket may already be closing */}
    }

    // Wait for the completer (resolved by _handleServerMessage on FINAL result).
    // Adding a timeout: if Oracle doesn't respond to STOP with a final result
    // within a reasonable time, just return what we have so far to avoid hanging.
    final result = await (_transcriptCompleter?.future ?? Future.value(''))
        .timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        debugPrint('⚠️ OCI STOP Response Timeout! Proceeding with current segments.');
        return _finalSegments.join(' ').trim();
      },
    );

    // Force close the websocket to ensure clean state
    await _cleanup();
    return result;
  }

  Future<void> dispose() => _cleanup();

  // ═══════════════════════════════════════════════════════════════════════════
  // Step 1: Obtain Realtime Session Token
  // ═══════════════════════════════════════════════════════════════════════════

  Future<String> _createRealtimeSessionToken() async {
    final url =
        '$_httpsEndpoint/20220101/actions/createRealtimeSessionToken';

    final body = jsonEncode({
      'compartmentId': credentials.compartmentId,
    });
    final bodyBytes = Uint8List.fromList(utf8.encode(body));

    final signer = OciRequestSigner(
      tenancyId: credentials.tenancyId,
      userId: credentials.userId,
      fingerprint: credentials.fingerprint,
      privateKeyPem: credentials.privateKeyPem,
    );

    final signedHeaders = signer.signRequest(
      method: 'POST',
      url: url,
      body: bodyBytes,
    );

    final response = await http.post(
      Uri.parse(url),
      headers: signedHeaders,
      body: bodyBytes,
    );

    if (response.statusCode != 200) {
      throw Exception(
          'OCI Session Token Error [${response.statusCode}]: ${response.body}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    // OCI returns: { "token": "<JWT>", "sessionId": "..." }
    final token = json['token'] as String?;
    if (token == null || token.isEmpty) {
      throw Exception('OCI auth response missing token: ${response.body}');
    }
    debugPrint('✅ OCI Session Token obtained');
    return token;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Step 2: Open WebSocket
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _openWebSocket(String sessionToken) async {
    // The session token is passed as a query param on the WSS URL.
    final wsUri = Uri.parse(
      '$_wssEndpoint/ws/transcribe/stream?'
      'token=${Uri.encodeComponent(sessionToken)}',
    );

    _channel = WebSocketChannel.connect(wsUri);

    // Wait for the connection to be established.
    await _channel!.ready;

    // Send the opening configuration message.
    _channel!.sink.add(jsonEncode(_buildConfig()));
    debugPrint('✅ OCI WebSocket connected. Streaming audio now...');

    // Listen to server messages.
    _wsSubscription = _channel!.stream.listen(
      _handleServerMessage,
      onError: (e) {
        debugPrint('❌ OCI WebSocket error: $e');
        _setState(OracleSpeechState.error);
        onError?.call(e);
        if (!(_transcriptCompleter?.isCompleted ?? true)) {
          _transcriptCompleter?.completeError(e);
        }
      },
      onDone: () {
        debugPrint('🔌 OCI WebSocket closed.');
        // If we never received a FINAL result, resolve with what we have.
        if (!(_transcriptCompleter?.isCompleted ?? true)) {
          _transcriptCompleter?.complete(_finalSegments.join(' ').trim());
        }
        _setState(OracleSpeechState.done);
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Step 3: Stream audio chunks
  // ═══════════════════════════════════════════════════════════════════════════

  void _streamAudio(Stream<Uint8List> audioChunks) {
    _audioSubscription = audioChunks.listen(
      (chunk) {
        if (_channel != null &&
            (_state == OracleSpeechState.ready ||
                _state == OracleSpeechState.finalizing)) {
          // OCI expects raw binary audio frames over the WebSocket.
          _channel!.sink.add(chunk);
        }
      },
      onError: (e) {
        debugPrint('Audio stream error: $e');
        onError?.call(e);
      },
      onDone: () {
        debugPrint('Audio stream ended naturally.');
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Handle server messages
  // ═══════════════════════════════════════════════════════════════════════════

  void _handleServerMessage(dynamic raw) {
    try {
      final Map<String, dynamic> msg = jsonDecode(raw as String);
      final event = msg['event'] as String? ?? '';

      debugPrint('OCI ← $event');

      switch (event) {
        case 'RESULT':
          _handleResult(msg);
          break;
        case 'ACKMESSAGE':
        case 'CONNECT':
          // Config acknowledgement — no action needed.
          break;
        case 'ERROR':
          final errMsg = msg['message'] ?? msg['errorMessage'] ?? 'Unknown OCI error';
          debugPrint('❌ OCI Server Error: $errMsg');
          _setState(OracleSpeechState.error);
          if (!(_transcriptCompleter?.isCompleted ?? true)) {
            _transcriptCompleter?.completeError(Exception(errMsg));
          }
          break;
        default:
          debugPrint('OCI unknown event: $raw');
      }
    } catch (e) {
      debugPrint('Failed to parse OCI message: $e  raw=$raw');
    }
  }

  void _handleResult(Map<String, dynamic> msg) {
    // OCI result structure:
    // { "event": "RESULT", "transcriptions": [ { "transcription": "...", "isFinal": true, ... } ] }
    final transcriptions = msg['transcriptions'] as List<dynamic>? ?? [];

    for (final t in transcriptions) {
      final isFinal = t['isFinal'] as bool? ?? false;
      final text = t['transcription'] as String? ?? '';

      if (isFinal && text.isNotEmpty) {
        debugPrint('✅ OCI Final: $text');
        _finalSegments.add(text);
      } else if (!isFinal) {
        // 🎯 Intentionally ignored per product requirement:
        // "Ignore partial results — show only final result after Stop."
        debugPrint('ℹ️ OCI Partial (ignored): $text');
      }
    }

    // 🔚 If the server signals this is the last result batch (isFinal on all),
    // and we are in finalizing mode, resolve the completer.
    if (_state == OracleSpeechState.finalizing) {
      final allFinal = transcriptions.every(
          (t) => (t['isFinal'] as bool? ?? false));
      if (allFinal && transcriptions.isNotEmpty) {
        if (!(_transcriptCompleter?.isCompleted ?? true)) {
          final fullTranscript = _finalSegments.join(' ').trim();
          _transcriptCompleter?.complete(fullTranscript);
        }
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Build the OCI realtime config JSON message
  // ═══════════════════════════════════════════════════════════════════════════

  Map<String, dynamic> _buildConfig() {
    // Common params for both models
    final config = <String, dynamic>{
      'event': 'SEND_FINAL_SILENCE_THRESHOLD',
      'compartmentId': credentials.compartmentId,
      'transcriptionProperties': <String, dynamic>{
        'languageCode': language,
        // ⚠️ ORACLE DOCUMENTATION TRAP:
        // The params below are ONLY valid for modelType == "ORACLE".
        // If sent with "WHISPER", OCI returns "Connection Refused".
        // They are added conditionally below.
      },
    };

    final transcriptionProps =
        config['transcriptionProperties'] as Map<String, dynamic>;

    if (model == OracleSTTModel.oracleMedical) {
      // ── Oracle Medical ────────────────────────────────────────────────────
      transcriptionProps['modelDetails'] = {
        'modelType': 'ORACLE',
        'domain': 'MEDICAL',
      };
      // These parameters are ALLOWED only with ORACLE model:
      transcriptionProps['partialSilenceThresholdInMs'] = 0;
      transcriptionProps['finalSilenceThresholdInMs'] = 2000;
      transcriptionProps['stabilizePartialResults'] = 'NONE';
      transcriptionProps['shouldIgnoreInvalidCustomizations'] = false;
    } else {
      // ── Whisper Generic ───────────────────────────────────────────────────
      // ⚠️ STRICTLY OMIT: partialSilenceThresholdInMs, finalSilenceThresholdInMs,
      //                    stabilizePartialResults, shouldIgnoreInvalidCustomizations,
      //                    customizations — sending any of these causes Connection Refused.
      transcriptionProps['modelDetails'] = {
        'modelType': 'WHISPER',
        'domain': 'GENERIC',
      };
      // Do NOT add any of the forbidden params here.
    }

    return config;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Helpers
  // ═══════════════════════════════════════════════════════════════════════════

  void _setState(OracleSpeechState newState) {
    _state = newState;
    onStateChange?.call(newState);
  }

  Future<void> _cleanup() async {
    await _audioSubscription?.cancel();
    await _wsSubscription?.cancel();
    await _channel?.sink.close();
    _audioSubscription = null;
    _wsSubscription = null;
    _channel = null;
    _setState(OracleSpeechState.idle);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// OciCredentials — credential bag (loaded from SharedPreferences / .env)
// ─────────────────────────────────────────────────────────────────────────────

class OciCredentials {
  final String tenancyId;
  final String userId;
  final String fingerprint;
  final String compartmentId;
  final String privateKeyPem;

  const OciCredentials({
    required this.tenancyId,
    required this.userId,
    required this.fingerprint,
    required this.compartmentId,
    required this.privateKeyPem,
  });
}
