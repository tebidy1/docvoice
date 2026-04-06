import 'dart:async';
import 'dart:convert';
// dart:typed_data provided transitively by flutter/foundation.dart
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soutnote/core/services/oci_request_signer.dart';

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
  // (_httpsEndpoint removed — no longer making REST calls)

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
      // Step 1: Open WebSocket with config in query params.
      _setState(OracleSpeechState.connecting);
      await _openWebSocket();

      // Step 2: Send CREDENTIALS authentication message.
      _setState(OracleSpeechState.authenticating);
      await _sendCredentials();

      // Step 3: Start streaming audio.
      _setState(OracleSpeechState.ready);
      _streamAudio(audioChunks);
    } catch (e) {
      _setState(OracleSpeechState.error);
      onError?.call(e);
      if (!(_transcriptCompleter?.isCompleted ?? true)) {
        _transcriptCompleter?.completeError(e);
      }
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
        _channel!.sink.add(jsonEncode({'event': 'SEND_FINAL_RESULT'}));
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
  // Step 1: Open WebSocket (config params in URL query string)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Builds the WebSocket URL query string dynamically based on the selected
  /// model. Verified working profiles via Node.js WebSocket test:
  ///
  /// ORACLE MEDICAL: ?isAckEnabled=false&encoding=audio/raw;rate=16000
  ///   &modelType=ORACLE&modelDomain=MEDICAL&languageCode=en-US
  ///   &finalSilenceThresholdInMs=2000
  ///
  /// WHISPER Arabic: ?isAckEnabled=false&encoding=audio/raw;rate=16000
  ///   &modelType=WHISPER&languageCode=ar
  ///   (⚠️ NO modelDomain, NO silence thresholds, NO stabilizePartialResults)
  String _buildWsQueryParams() {
    final params = <String>[
      'isAckEnabled=false',
      'encoding=audio/raw;rate=16000',
    ];

    if (model == OracleSTTModel.oracleMedical) {
      // ── Oracle Medical (English only) ─────────────────────────────────
      params.addAll([
        'modelType=ORACLE',
        'modelDomain=MEDICAL',
        'languageCode=en-US',
        'finalSilenceThresholdInMs=2000',
      ]);
    } else {
      // ── Whisper Generic (Arabic) ──────────────────────────────────────
      // ⚠️ STRICTLY FORBIDDEN: modelDomain, partialSilenceThresholdInMs,
      //    finalSilenceThresholdInMs, stabilizePartialResults,
      //    shouldIgnoreInvalidCustomizations — ANY of these causes 400.
      params.addAll([
        'modelType=WHISPER',
        'languageCode=auto',
      ]);
    }

    return params.join('&');
  }

  Future<void> _openWebSocket() async {
    final queryParams = _buildWsQueryParams();
    // CRITICAL: Use Uri() constructor, NOT Uri.parse()!
    // BUT DO NOT pass the raw pre-joined string to `query:` because Dart
    // will percent-encode '=' and '&'! We must use `query` but we need to
    // be careful. Actually, `queryParameters` would URL-encode the `;` in
    // raw;rate=16000. So we must inject the query manually or use parse!
    // Wait, earlier we were using Uri.parse which mangled it? No, Uri.parse
    // is fine as long as the string is valid!
    final wsUri = Uri.parse(
      'wss://realtime.aiservice.$_region.oci.oraclecloud.com/ws/transcribe/stream?$queryParams'
    );

    debugPrint('OCI WS connecting to: $wsUri');
    _channel = WebSocketChannel.connect(wsUri);

    // Wait for the WebSocket handshake (HTTP 101 Upgrade).
    await _channel!.ready;
    debugPrint('✅ OCI WebSocket connected (HTTP 101 Upgrade succeeded)');

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
        if (!(_transcriptCompleter?.isCompleted ?? true)) {
          _transcriptCompleter?.complete(_finalSegments.join(' ').trim());
        }
        _setState(OracleSpeechState.done);
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Step 2: Fetch Token (PROVEN TO WORK) & Send via WS
  // ═══════════════════════════════════════════════════════════════════════════

  Future<String> _createRealtimeSessionToken() async {
    // 🌐 WEB FALLBACK: Browsers block custom Date/Host headers required for OCI Signature.
    // We must route the token request through the backend proxy.
    if (kIsWeb) {
      debugPrint('Fetching Token from Backend Proxy (Web)...');
      try {
        // Import ApiService locally or use a global instance. We'll use http directly 
        // to avoid circular dependencies, pointing to the same endpoint.
        // Assuming ApiService is available or we use http with the base URL.
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('auth_token');
        // Fallback baseUrl if dotenv not loaded here
        final baseUrl = 'https://docapi.sootnote.com/api'; 
        
        final response = await http.get(
          Uri.parse('$baseUrl/audio/oracle-token'),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
        );

        if (response.statusCode == 200) {
          final jsonResponse = jsonDecode(response.body);
          if (jsonResponse['status'] == true && jsonResponse['token'] != null) {
             return jsonResponse['token'] as String;
          }
          if (jsonResponse['token'] != null) {
             return jsonResponse['token'] as String; 
          }
        }
        throw Exception('Backend Oracle Token endpoint failed: HTTP ${response.statusCode} - ${response.body}. Hint: Ensure /api/audio/oracle-token exists in Laravel.');
      } catch (e) {
        throw Exception('Web Oracle Auth Error: $e');
      }
    }

    // 📱 MOBILE/DESKTOP: Direct OCI Signature (works perfectly)
    final signer = OciRequestSigner(
      tenancyId: credentials.tenancyId,
      userId: credentials.userId,
      fingerprint: credentials.fingerprint,
      privateKeyPem: credentials.privateKeyPem,
    );

    final host = 'speech.aiservice.$_region.oci.oraclecloud.com';
    final targetUri = Uri.parse('https://$host/20220101/actions/realtimeSessionToken');

    final body = jsonEncode({
      "compartmentId": credentials.compartmentId,
    });

    final headers = signer.signRequest(
      method: "POST",
      url: targetUri.toString(),
      body: utf8.encode(body),
    );
    // Remove pseudo header
    headers.remove('(request-target)');

    // Add required content headers
    headers['Content-Type'] = 'application/json';
    headers['Content-Length'] = utf8.encode(body).length.toString();

    debugPrint('Fetching Token from: $targetUri');
    final response = await http.post(
      targetUri,
      headers: headers,
      body: body,
    );

    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(response.body);
      return jsonResponse['token'] as String;
    } else {
      throw Exception('Failed to get realtime session token: HTTP ${response.statusCode} - ${response.body}');
    }
  }

  Future<void> _sendCredentials() async {
    try {
      final token = await _createRealtimeSessionToken();
      debugPrint('✅ OCI Token acquired successfully (HTTP 200)');

      final authMessage = jsonEncode({
        'authenticationType': 'TOKEN',
        'token': token,
        'compartmentId': credentials.compartmentId,
      });

      _channel!.sink.add(authMessage);
      debugPrint('✅ OCI TOKEN auth message sent over WebSocket');
    } catch (e) {
      debugPrint('❌ OCI Token generation failed: $e');
      rethrow;
    }
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

  // (_buildConfig removed — config is now in the WebSocket URL query string)

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
// OciCredentials — credential bag (loaded from SharedPreferences)
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
