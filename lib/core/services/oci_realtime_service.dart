import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../network/api_client.dart';

enum RealtimeStatus { idle, connecting, authenticated, error, unavailable }

enum SpeechModel { whisper, oracleMedical }

class OciRealtimeService {
  WebSocketChannel? _ws;
  StreamSubscription? _wsSubscription;
  Stream<Uint8List>? _audioStream;
  StreamSubscription? _audioSubscription;

  bool _isAuthenticated = false;
  bool _isConnecting = false;
  String _committedTranscript = '';
  int _endpointIndex = 0;

  final List<Uint8List> _pcmBuffer = [];
  bool _collectingPcm = false;

  RealtimeStatus _status = RealtimeStatus.idle;
  RealtimeStatus get status => _status;

  String _realtimeTranscript = '';
  String get realtimeTranscript => _realtimeTranscript;

  String _finalTranscript = '';
  String get finalTranscript => _finalTranscript;

  Timer? _connectionTimeout;
  Timer? _authTimeout;

  static const int _connectionTimeoutMs = 15000;

  Map<String, String>? _tokenData;

  static const int _tokenMaxAgeMs = 50 * 60 * 1000;
  Map<String, String>? _cachedToken;
  int _tokenFetchedAt = 0;
  Future<Map<String, String>?>? _prefetchPromise;

  SpeechModel _selectedModel = SpeechModel.whisper;

  final StreamController<String> _transcriptController =
      StreamController<String>.broadcast();
  Stream<String> get transcriptStream => _transcriptController.stream;

  final StreamController<RealtimeStatus> _statusController =
      StreamController<RealtimeStatus>.broadcast();
  Stream<RealtimeStatus> get statusStream => _statusController.stream;

  Uint8List get pcmBufferAsWav => _buildWavFromPcmBuffer();

  void _updateStatus(RealtimeStatus newStatus) {
    _status = newStatus;
    _statusController.add(newStatus);
  }

  void _emitTranscript() {
    _transcriptController.add(_realtimeTranscript);
  }

  Uint8List _buildWavFromPcmBuffer() {
    int totalPcmBytes = 0;
    for (final chunk in _pcmBuffer) {
      totalPcmBytes += chunk.length;
    }

    final header = Uint8List(44);
    final bd = ByteData.view(header.buffer);

    header[0] = 0x52;
    header[1] = 0x49;
    header[2] = 0x46;
    header[3] = 0x46; // RIFF
    bd.setUint32(4, 36 + totalPcmBytes, Endian.little);
    header[8] = 0x57;
    header[9] = 0x41;
    header[10] = 0x56;
    header[11] = 0x45; // WAVE
    header[12] = 0x66;
    header[13] = 0x6d;
    header[14] = 0x74;
    header[15] = 0x20; // fmt
    bd.setUint32(16, 16, Endian.little);
    bd.setUint16(20, 1, Endian.little); // PCM
    bd.setUint16(22, 1, Endian.little); // mono
    bd.setUint32(24, 16000, Endian.little); // sample rate
    bd.setUint32(28, 32000, Endian.little); // byte rate
    bd.setUint16(32, 2, Endian.little); // block align
    bd.setUint16(34, 16, Endian.little); // bits per sample
    header[36] = 0x64;
    header[37] = 0x61;
    header[38] = 0x74;
    header[39] = 0x61; // data
    bd.setUint32(40, totalPcmBytes, Endian.little);

    final result = BytesBuilder();
    result.add(header);
    for (final chunk in _pcmBuffer) {
      result.add(chunk);
    }

    return result.toBytes();
  }

  void startPcmCollection() {
    _pcmBuffer.clear();
    _collectingPcm = true;
  }

  void addPcmChunk(Uint8List chunk) {
    if (_collectingPcm) {
      _pcmBuffer.add(chunk);
    }
  }

  void stopPcmCollection() {
    _collectingPcm = false;
  }

  Future<void> prefetchToken() async {
    if (_isCachedTokenValid()) {
      debugPrint('Token already cached, skipping prefetch.');
      return;
    }
    debugPrint('Pre-fetching Oracle token in background...');
    _prefetchPromise = _fetchTokenFromApi();
    final result = await _prefetchPromise;
    _prefetchPromise = null;
    if (result != null) {
      _cachedToken = result;
      _tokenFetchedAt = DateTime.now().millisecondsSinceEpoch;
      debugPrint('Token pre-fetched and cached.');
    }
  }

  bool _isCachedTokenValid() {
    return _cachedToken != null &&
        (DateTime.now().millisecondsSinceEpoch - _tokenFetchedAt) <
            _tokenMaxAgeMs;
  }

  Future<Map<String, String>?> _getToken() async {
    if (_prefetchPromise != null) {
      debugPrint('Waiting for in-flight token prefetch...');
      await _prefetchPromise;
    }

    if (_isCachedTokenValid()) {
      debugPrint('Using cached token.');
      final validToken = _cachedToken!;
      _cachedToken = null;
      _tokenFetchedAt = 0;
      return validToken;
    }

    debugPrint('Cache miss - fetching fresh token...');
    return await _fetchTokenFromApi();
  }

  Future<Map<String, String>?> _fetchTokenFromApi() async {
    try {
      final apiClient = ApiClient();
      final response = await apiClient.getOracleToken();

      final payload = response['payload'] ?? response['data'] ?? response;
      final token = payload['token'] as String?;
      final region = payload['region'] as String?;
      final compartmentId = payload['compartmentId'] as String?;

      if (token == null || region == null || compartmentId == null) {
        debugPrint('Missing OCI fields in token response.');
        _setUnavailable();
        return null;
      }

      debugPrint('OCI Token received, region: $region');
      return {'token': token, 'region': region, 'compartmentId': compartmentId};
    } catch (e) {
      debugPrint('Failed to fetch OCI token: $e');
      _setUnavailable();
      return null;
    }
  }

  Future<void> loadModelPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final engine = prefs.getString('stt_engine_pref') ?? 'oracle_live';
    _selectedModel = engine == 'oracle_medical'
        ? SpeechModel.oracleMedical
        : SpeechModel.whisper;
  }

  List<String> _getEndpoints(String region) {
    return [
      'wss://realtime.aiservice.$region.oci.oraclecloud.com/ws/transcribe/stream',
      'wss://speech.aiservice.$region.oci.oraclecloud.com/ws/transcribe/stream',
    ];
  }

  Map<String, dynamic> _buildSessionConfig() {
    final config = <String, dynamic>{
      'languageCode': _selectedModel == SpeechModel.whisper ? 'en-US' : 'en-US',
      'modelDomain':
          _selectedModel == SpeechModel.whisper ? 'GENERIC' : 'MEDICAL',
      'modelType': _selectedModel == SpeechModel.whisper ? 'WHISPER' : 'ORACLE',
      'encoding': 'audio/raw;rate=16000',
      'isAckEnabled': false,
      'punctuation': 'AUTO',
    };

    if (_selectedModel == SpeechModel.oracleMedical) {
      config['partialSilenceThresholdInMs'] = 1000;
      config['finalSilenceThresholdInMs'] = 2000;
      config['stabilizePartialResults'] = 'MEDIUM';
    }

    return config;
  }

  Future<void> startTranscription(Stream<Uint8List> audioStream) async {
    _audioStream = audioStream;
    _committedTranscript = '';
    _isAuthenticated = false;
    _endpointIndex = 0;
    _realtimeTranscript = '';
    _finalTranscript = '';
    _updateStatus(RealtimeStatus.connecting);

    await loadModelPreference();

    try {
      final fetched = await _getToken();
      if (fetched == null) return;
      _tokenData = fetched;
      _tryNextEndpoint();
    } catch (e) {
      debugPrint('Failed to start OCI real-time transcription: $e');
      _setUnavailable();
    }
  }

  void _tryNextEndpoint() {
    if (_tokenData == null) {
      _setUnavailable();
      return;
    }

    final endpoints = _getEndpoints(_tokenData!['region']!);

    if (_endpointIndex >= endpoints.length) {
      debugPrint('All OCI realtime endpoints failed.');
      _setUnavailable();
      return;
    }

    final wsUrl = endpoints[_endpointIndex];
    debugPrint(
        'OCI connecting (${_endpointIndex + 1}/${endpoints.length}): $wsUrl');
    _isConnecting = true;
    _cleanupWebSocket();

    final uri = Uri.parse(wsUrl);
    _ws = WebSocketChannel.connect(uri);

    _connectionTimeout =
        Timer(const Duration(milliseconds: _connectionTimeoutMs), () {
      debugPrint('Connection+auth timeout for $wsUrl');
      _endpointIndex++;
      _tryNextEndpoint();
    });

    _ws!.ready.then((_) {
      debugPrint('WebSocket handshake complete for $wsUrl');
      _clearConnectionTimeout();

      final authPayload = {
        'authenticationType': 'TOKEN',
        'compartmentId': _tokenData!['compartmentId'],
        'token': _tokenData!['token'],
      };
      debugPrint('Sending auth payload...');
      _ws!.sink.add(jsonEncode(authPayload));
    }).catchError((error) {
      debugPrint('WebSocket ready error: $error');
      _clearConnectionTimeout();
      _endpointIndex++;
      _tryNextEndpoint();
    });

    _wsSubscription = _ws!.stream.listen(
      (data) {
        if (data is String) {
          _handleMessage(data);
        }
      },
      onDone: () {
        _clearConnectionTimeout();
        _clearAuthTimeout();

        if (_isAuthenticated) {
          debugPrint('OCI WebSocket closed normally.');
          _cleanupAudio();
          if (_status == RealtimeStatus.authenticated) {
            _updateStatus(RealtimeStatus.idle);
          }
        } else if (_isConnecting) {
          debugPrint('WebSocket closed before auth.');
          _endpointIndex++;
          _tryNextEndpoint();
        }
      },
      onError: (error) {
        _clearConnectionTimeout();
        _clearAuthTimeout();

        if (_isConnecting && !_isAuthenticated) {
          debugPrint('WebSocket error before auth - trying next endpoint.');
          _endpointIndex++;
          _tryNextEndpoint();
        }
      },
    );
  }

  void _handleMessage(String data) {
    try {
      final message = jsonDecode(data) as Map<String, dynamic>;
      final event = message['event'] as String?;

      debugPrint('OCI Message: $event');

      switch (event) {
        case 'CONNECT':
          _clearAuthTimeout();
          debugPrint('OCI CONNECT - authenticated successfully');
          _isAuthenticated = true;
          _isConnecting = false;
          _updateStatus(RealtimeStatus.authenticated);

          final sessionConfig = _buildSessionConfig();
          debugPrint('Sending session config: ${jsonEncode(sessionConfig)}');
          _ws!.sink.add(jsonEncode(sessionConfig));

          _startAudioStreaming();
          break;

        case 'RESULT':
          _handleTranscriptionResult(message);
          break;

        case 'ACKAUDIO':
          break;

        case 'ERROR':
          _clearAuthTimeout();
          final code = message['code'];
          final errorMsg = message['message'];
          debugPrint('OCI ERROR: $code $errorMsg');
          _isConnecting = false;
          _updateStatus(RealtimeStatus.error);
          break;
      }
    } catch (e) {
      debugPrint('Failed to parse OCI message: $e');
    }
  }

  void _handleTranscriptionResult(Map<String, dynamic> message) {
    final transcriptions = message['transcriptions'] as List<dynamic>? ?? [];

    String partialText = '';

    for (final t in transcriptions) {
      final text = t['transcription'] as String? ?? '';
      final isFinal = t['isFinal'] as bool? ?? false;

      if (isFinal) {
        if (_committedTranscript.isNotEmpty &&
            !_committedTranscript.endsWith(' ')) {
          _committedTranscript += ' ';
        }
        _committedTranscript += text;
      } else {
        partialText = text;
      }
    }

    _realtimeTranscript = _committedTranscript +
        (_committedTranscript.isNotEmpty && partialText.isNotEmpty ? ' ' : '') +
        partialText;

    _finalTranscript = _committedTranscript;

    _emitTranscript();
  }

  void _startAudioStreaming() {
    if (_audioStream == null || !_isAuthenticated) return;

    _audioSubscription = _audioStream!.listen(
      (pcmData) {
        if (!_isAuthenticated || _ws == null) return;
        try {
          _ws!.sink.add(pcmData);
        } catch (e) {
          debugPrint('Failed to send audio chunk: $e');
        }
      },
      onError: (e) {
        debugPrint('Audio stream error: $e');
      },
      onDone: () {
        debugPrint('Audio stream done.');
      },
    );

    debugPrint('Audio streaming started - 16kHz PCM via WebSocket');
  }

  void _setUnavailable() {
    _isConnecting = false;
    _cleanupWebSocket();
    debugPrint(
        'OCI Realtime Speech unavailable! Falling back to Batch processing.');
    _updateStatus(RealtimeStatus.unavailable);
  }

  void _clearConnectionTimeout() {
    _connectionTimeout?.cancel();
    _connectionTimeout = null;
  }

  void _clearAuthTimeout() {
    _authTimeout?.cancel();
    _authTimeout = null;
  }

  void requestFinalResult() {
    if (_ws != null && _isAuthenticated) {
      try {
        _ws!.sink.add(jsonEncode({'event': 'SEND_FINAL_RESULT'}));
      } catch (e) {
        debugPrint('Failed to request final result: $e');
      }
    }
  }

  void stopTranscription() {
    _clearConnectionTimeout();
    _clearAuthTimeout();
    _isConnecting = false;

    requestFinalResult();

    _cleanupWebSocket();
    _cleanupAudio();

    _audioStream = null;
    _committedTranscript = '';
    _tokenData = null;
    _updateStatus(RealtimeStatus.idle);

    debugPrint('Real-time transcription stopped');

    prefetchToken().catchError((e) {
      debugPrint('Prefetch failed: $e');
    });
  }

  void _cleanupWebSocket() {
    _wsSubscription?.cancel();
    _wsSubscription = null;
    if (_ws != null) {
      try {
        _ws!.sink.close();
      } catch (_) {}
      _ws = null;
    }
  }

  void _cleanupAudio() {
    _audioSubscription?.cancel();
    _audioSubscription = null;
    _isAuthenticated = false;
  }

  void dispose() {
    _cleanupWebSocket();
    _cleanupAudio();
    _clearConnectionTimeout();
    _clearAuthTimeout();
    _transcriptController.close();
    _statusController.close();
  }
}
