import 'dart:async';
import 'dart:convert';

// dart:typed_data provided transitively by flutter/foundation.dart
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../config/api_config.dart';
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
  ready, // WebSocket open, streaming audio
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

  // ── Backend-provided config (from token endpoint) ──────────────────────────
  String? _backendRegion;
  String? _backendCompartmentId;

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
      if (kIsWeb) {
        // ── WEB FLOW ─────────────────────────────────────────────────────
        // Browsers CANNOT send custom headers (Authorization, Date, Host)
        // during the WebSocket handshake — this is a hard browser security
        // restriction. Oracle returns HTTP 400 if auth is missing from the
        // handshake. Solution: fetch the session token FIRST via the backend
        // proxy, then embed it as `&token=<TOKEN>` in the WebSocket URL.
        // Oracle accepts this form of auth inline in the query string.
        _setState(OracleSpeechState.authenticating);
        debugPrint('🌐 Web: Fetching Oracle token from backend proxy first...');
        final tokenData = await _createRealtimeSessionToken();
        final webToken = tokenData['token'] as String;
        _backendRegion = tokenData['region'] as String?;
        _backendCompartmentId = tokenData['compartmentId'] as String?;

        debugPrint('✅ Web: Token acquired (length: ${webToken.length})');
        debugPrint('✅ Web: Region from backend: $_backendRegion');
        debugPrint('✅ Web: CompartmentId from backend: $_backendCompartmentId');

        // Debug: Decode JWT token to check expiration
        _debugDecodeToken(webToken);

        if (webToken.isEmpty) {
          throw Exception('Received empty token from backend');
        }

        // Step 2: Open WebSocket with token embedded in URL (web only).
        _setState(OracleSpeechState.connecting);
        debugPrint(
            '🔌 Calling _openWebSocket with inlineToken (length: ${webToken.length})');
        await _openWebSocket(inlineToken: webToken);
      } else {
        // ── MOBILE / DESKTOP FLOW ────────────────────────────────────────
        // Fetch token FIRST, before opening the WS connection,
        // so we can authenticate immediately and avoid server disconnects.
        _setState(OracleSpeechState.authenticating);
        final tokenData = await _createRealtimeSessionToken();
        final token = tokenData['token'] as String;

        _setState(OracleSpeechState.connecting);
        await _openWebSocket();

        // Step 2: Send CREDENTIALS authentication message.
        await _sendCredentials(token);
      }

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
    final result =
        await (_transcriptCompleter?.future ?? Future.value('')).timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        debugPrint(
            '⚠️ OCI STOP Response Timeout! Proceeding with current segments.');
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
  /// ORACLE MEDICAL: ?isAckEnabled=true&encoding=audio/raw;rate=16000
  ///   &modelType=ORACLE&modelDomain=MEDICAL&languageCode=en-US
  ///   &finalSilenceThresholdInMs=2000
  ///
  /// WHISPER Arabic: ?isAckEnabled=false&encoding=audio/raw;rate=16000
  ///   &modelType=WHISPER&languageCode=ar
  ///   (⚠️ NO modelDomain, NO silence thresholds, NO stabilizePartialResults)
  /// Builds the WebSocket URL query string.
  ///
  /// [inlineToken] — when provided (web only), the session token is appended
  /// as `&token=<TOKEN>` so Oracle can authenticate the WS handshake without
  /// custom headers (which browsers block).
  String _buildWsQueryParams({String? inlineToken}) {
    final params = <String>[];

    // 🌐 WEB AUTH: token and compartmentId should ideally be first
    if (inlineToken != null && inlineToken.isNotEmpty) {
      params.add('token=${Uri.encodeComponent(inlineToken)}');

      // Use backend-provided compartmentId if available, otherwise use credentials
      final compartmentId = _backendCompartmentId ?? credentials.compartmentId;
      if (compartmentId.isEmpty) {
        debugPrint('❌ ERROR: compartmentId is empty!');
        throw Exception('compartmentId is required but not configured');
      }
      params.add('compartmentId=${Uri.encodeComponent(compartmentId)}');
      debugPrint(
          '🔑 WebSocket Auth: token (len=${inlineToken.length}) and compartmentId (len=${compartmentId.length}) added to URL');
      if (_backendCompartmentId != null) {
        debugPrint('   (Using compartmentId from backend)');
      }
    } else {
      debugPrint(
          '⚠️ WebSocket Auth: inlineToken is null or empty! Token value: "$inlineToken"');
    }

    // Standard params - different for each model type
    // ⚠️ Oracle MEDICAL uses isAckEnabled=true
    // ⚠️ WHISPER uses isAckEnabled=false (per Oracle docs)
    if (model == OracleSTTModel.oracleMedical) {
      params.addAll([
        'isAckEnabled=true',
        'encoding=audio%2Fraw%3Brate%3D16000', // URI-encoded: audio/raw;rate=16000
        'modelType=ORACLE',
        'modelDomain=MEDICAL',
        'languageCode=en-US',
      ]);
    } else {
      // WHISPER model - different parameter set
      // Note: Oracle WHISPER uses 'ar' not 'ar-SA' for Arabic
      params.addAll([
        'isAckEnabled=false',
        'encoding=audio%2Fraw%3Brate%3D16000', // URI-encoded: audio/raw;rate=16000
        'modelType=WHISPER',
        'languageCode=ar',
      ]);
    }

    return params.join('&');
  }

  /// Opens the Oracle WebSocket connection.
  ///
  /// On web, pass [inlineToken] to embed the session token in the URL query
  /// string — browsers cannot send custom `Authorization` headers during the
  /// WebSocket handshake, so the token must be in the URL.
  Future<void> _openWebSocket({String? inlineToken}) async {
    final queryParams = _buildWsQueryParams(inlineToken: inlineToken);

    // Debug: Print the query params string
    debugPrint(
        'Query params string: ${queryParams.replaceAll(inlineToken ?? '', '<TOKEN>')}');

    // Use backend-provided region if available, otherwise use default
    final region = _backendRegion ?? _region;
    if (_backendRegion != null) {
      debugPrint('🌍 Using region from backend: $region');
    }

    // Build the URL as a string first
    // ⚠️ IMPORTANT: We use the string directly to avoid Dart's Uri class
    // re-encoding special characters like semicolons.
    final wsUrlString =
        'wss://realtime.aiservice.$region.oci.oraclecloud.com/ws/transcribe/stream?$queryParams';

    // Log without the full token for security
    final logUrl = inlineToken != null
        ? wsUrlString.replaceAll(inlineToken, '<REDACTED>')
        : wsUrlString;
    debugPrint('OCI WS connecting to: $logUrl');

    // Parse to Uri for the WebSocketChannel, but note that this may re-encode
    // some characters. The WebSocketChannel will use the Uri's toString().
    final wsUri = Uri.parse(wsUrlString);

    // Debug: Print the actual URL that WebSocketChannel will use
    final uriString = wsUri.toString();
    debugPrint(
        'WebSocket URL (from Uri): ${uriString.replaceAll(inlineToken ?? '', '<TOKEN>')}');

    // Verify token is actually in the URL
    if (inlineToken != null &&
        !uriString.contains(
            inlineToken.substring(0, (inlineToken.length / 2).round()))) {
      debugPrint('⚠️ WARNING: Token may not be properly included in the URL!');
    }

    // For Web, construct WebSocket URL differently to preserve exact encoding
    if (kIsWeb) {
      // On web, use the URL string directly to avoid Uri.parse re-encoding
      // The WebSocket browser API will handle the URL correctly
      final wsUriForWeb = Uri.parse(wsUrlString);
      _channel = WebSocketChannel.connect(wsUriForWeb);
    } else {
      _channel = WebSocketChannel.connect(wsUri);
    }

    // Wait for the WebSocket handshake (HTTP 101 Upgrade).
    try {
      await _channel!.ready;
      debugPrint('✅ OCI WebSocket connected (HTTP 101 Upgrade succeeded)');
    } catch (e) {
      debugPrint('❌ OCI WebSocket handshake failed: $e');
      debugPrint('   URL: ${logUrl.replaceAll(inlineToken ?? '', '<TOKEN>')}');
      debugPrint('   Possible causes:');
      debugPrint('   1. Invalid or expired token from backend');
      debugPrint('   2. Wrong compartmentId configured');
      debugPrint(
          '   3. Oracle Speech service not enabled for this compartment');
      debugPrint('   4. Network/firewall issues');
      rethrow;
    }

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

  Future<Map<String, dynamic>> _createRealtimeSessionToken() async {
    // 🌐 WEB FALLBACK: Browsers block custom Date/Host headers required for OCI Signature.
    // We must route the token request through the backend proxy.
    if (kIsWeb) {
      debugPrint('Fetching Token from Backend Proxy (Web)...');
      try {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('auth_token');

        // Use centralized baseUrl from ApiConfig - strictly no fallback
        final baseUrl = ApiConfig.baseUrl;

        if (baseUrl.isEmpty) {
          throw Exception('API_BASE_URL is not configured in environment');
        }

        final tokenUrl = '$baseUrl/audio/oracle-token';
        debugPrint('Web Token Proxy Request to: $tokenUrl');

        final response = await http.get(
          Uri.parse(tokenUrl),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
        );

        debugPrint('Web Token Proxy Response Status: ${response.statusCode}');
        debugPrint('Web Token Proxy Response Body: ${response.body}');

        if (response.statusCode == 200) {
          final jsonResponse = jsonDecode(response.body);
          debugPrint('Parsed JSON Response: $jsonResponse');

          if (jsonResponse['status'] == true && jsonResponse['token'] != null) {
            final token = jsonResponse['token'] as String;
            final region = jsonResponse['region'] as String?;
            final compartmentId = jsonResponse['compartmentId'] as String?;
            debugPrint(
                '✅ Token extracted successfully (length: ${token.length})');
            debugPrint('✅ Region from backend: $region');
            debugPrint('✅ CompartmentId from backend: $compartmentId');
            return {
              'token': token,
              'region': region,
              'compartmentId': compartmentId,
            };
          }
          if (jsonResponse['token'] != null) {
            final token = jsonResponse['token'] as String;
            final region = jsonResponse['region'] as String?;
            final compartmentId = jsonResponse['compartmentId'] as String?;
            debugPrint(
                '✅ Token extracted (no status check, length: ${token.length})');
            return {
              'token': token,
              'region': region,
              'compartmentId': compartmentId,
            };
          }
          debugPrint(
              '❌ Token not found in response. Keys: ${jsonResponse.keys.toList()}');
        }
        throw Exception(
            'Backend Oracle Token endpoint failed: HTTP ${response.statusCode} - ${response.body}');
      } catch (e) {
        debugPrint('Web Oracle Token Error: $e');
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
    final targetUri =
        Uri.parse('https://$host/20220101/actions/realtimeSessionToken');

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
      return {
        'token': jsonResponse['token'] as String,
        'region': _region,
        'compartmentId': credentials.compartmentId,
      };
    } else {
      throw Exception(
          'Failed to get realtime session token: HTTP ${response.statusCode} - ${response.body}');
    }
  }

  Future<void> _sendCredentials(String token) async {
    try {
      final authMessage = jsonEncode({
        'authenticationType': 'TOKEN',
        'token': token,
        'compartmentId': credentials.compartmentId,
      });

      _channel!.sink.add(authMessage);
      debugPrint('✅ OCI TOKEN auth message sent over WebSocket');
    } catch (e) {
      debugPrint('❌ OCI Token authentication failed: $e');
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
          try {
            _channel!.sink.add(chunk);
          } catch (e) {
            debugPrint('Ignored WebSocket write error: $e');
            // The connection might have closed abruptly before onDone fired.
          }
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
          final errMsg =
              msg['message'] ?? msg['errorMessage'] ?? 'Unknown OCI error';
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
      final allFinal =
          transcriptions.every((t) => (t['isFinal'] as bool? ?? false));
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

  /// Debug helper to decode JWT token and print its contents
  void _debugDecodeToken(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) {
        debugPrint(
            '⚠️ Invalid JWT format (expected 3 parts, got ${parts.length})');
        return;
      }

      // Decode payload (middle part)
      String payload = parts[1];
      // Add padding if needed
      while (payload.length % 4 != 0) {
        payload += '=';
      }

      final decoded = utf8.decode(base64Url.decode(payload));
      final json = jsonDecode(decoded);

      debugPrint('🔑 JWT Token Contents:');
      debugPrint('   sessionId: ${json['sessionId']}');
      debugPrint('   tenantId: ${json['tenantId']}');
      debugPrint(
          '   iat: ${json['iat']} (${DateTime.fromMillisecondsSinceEpoch(json['iat'] * 1000)})');
      debugPrint(
          '   exp: ${json['exp']} (${DateTime.fromMillisecondsSinceEpoch(json['exp'] * 1000)})');

      final exp = DateTime.fromMillisecondsSinceEpoch(json['exp'] * 1000);
      final now = DateTime.now();
      if (exp.isBefore(now)) {
        debugPrint('   ⚠️ TOKEN IS EXPIRED!');
      } else {
        debugPrint(
            '   ✅ Token is valid for ${exp.difference(now).inMinutes} more minutes');
      }
    } catch (e) {
      debugPrint('⚠️ Failed to decode token: $e');
    }
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
  final String? region; // Optional: can be provided from backend

  const OciCredentials({
    required this.tenancyId,
    required this.userId,
    required this.fingerprint,
    required this.compartmentId,
    required this.privateKeyPem,
    this.region,
  });
}
