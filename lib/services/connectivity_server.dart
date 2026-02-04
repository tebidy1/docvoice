import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../utils/wav_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/inbox_note.dart';
import '../mobile_app/models/note_model.dart';
import 'macro_service.dart';
import 'inbox_service.dart';
import 'api_service.dart';

class ConnectivityServer {
  HttpServer? _server;
  final List<WebSocketChannel> _clients = [];

  // Audio Buffer
  List<int> _audioBuffer = [];
  bool _isReceivingAudio = false;

  // Services
  final MacroService _macroService = MacroService();
  final ApiService _apiService = ApiService();

  // Stream for received text (Transcription)
  final _textStreamController = StreamController<String>.broadcast();
  Stream<String> get textStream => _textStreamController.stream;

  // Stream for connection status
  final _statusController = StreamController<String>.broadcast();
  Stream<String> get statusStream => _statusController.stream;

  // Stream for raw audio chunks (for visualization/debugging)
  final _audioStreamController = StreamController<List<int>>.broadcast();
  Stream<List<int>> get audioStream => _audioStreamController.stream;

  ConnectivityServer() {
    _macroService.init();
  }

  Future<void> startServer({int port = 8080}) async {
    await dotenv.load();
    await _macroService.init();

    var handler = webSocketHandler((WebSocketChannel webSocket) {
      _clients.add(webSocket);
      _statusController.add("Client Connected");
      print("Client connected");

      webSocket.stream.listen(
        (message) async {
          if (message is List<int>) {
            // Binary data -> Audio Chunk
            if (_isReceivingAudio) {
              _audioBuffer.addAll(message);
              _audioStreamController.add(message);
            }
          } else if (message is String) {
            // Text data -> Control messages
            print("Received message: $message");

            if (message == "START_RECORDING") {
              _isReceivingAudio = true;
              _audioBuffer.clear();
              _statusController.add("Receiving Audio...");
            } else if (message == "STOP_RECORDING") {
              _isReceivingAudio = false;
              _statusController.add("Processing Audio...");
              await processAudio(webSocket);
            } else if (message == "GET_MACROS") {
              final macrosJson = await _macroService.getMacrosAsJson();
              webSocket.sink.add(macrosJson);
            } else if (message.startsWith("SAVE_NOTE:")) {
              // Phase 3: Final Save from Mobile
              try {
                final jsonStr = message.substring(10);
                // We can parse generic JSON here. For now, let's treat it as the final content content.
                // Actually, let's look for a JSON object with { "text": "...", "patient": "..." }
                // Or just the raw text if simpler for now.
                // Let's assume JSON for extensibility.

                // For now, simpler: "SAVE_NOTE:Patient Name|Content" or just Content.
                // Let's stick to JSON in the implementation_plan logic.
                // But strictly, let's just save valid text to InboxService.

                // Direct service usage
                final InboxService inbox = InboxService();

                // Add as generic note
                final newId = await inbox.addNote(jsonStr);

                // Mark as Processed (Ready)
                await inbox.updateStatus(newId, NoteStatus.processed);

                _statusController.add("Saved from Mobile (Ready)");
                webSocket.sink.add("SAVED_ACK");
              } catch (e) {
                print("Error saving note: $e");
                webSocket.sink.add("ERROR:Save Failed");
              }
            } else if (message == "PING") {
              webSocket.sink.add("PONG");
            }
          }
        },
        onDone: () {
          _clients.remove(webSocket);
          _statusController.add("Client Disconnected");
          print("Client disconnected");
        },
        onError: (error) {
          print("WebSocket Error: $error");
          _clients.remove(webSocket);
        },
      );
    });

    try {
      // Listen on all interfaces (0.0.0.0) to allow mobile connection
      _server = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);
      print('Serving at ws://${_server?.address.address}:${_server?.port}');
      _statusController.add("Server Running on ${_server?.port}");
    } catch (e) {
      print("Error starting server: $e");
      _statusController.add("Server Error: $e");
    }
  }

  void addAudioData(List<int> data) {
    _audioBuffer.addAll(data);
    _audioStreamController.add(data);
  }

  /// Processes a complete WAV file directly
  Future<void> transcribeWav(Uint8List wavData,
      {WebSocketChannel? client}) async {
    _statusController.add("Transcribing...");

    try {
      // 1. Transcribe via Backend
      final transcriptionResult = await _apiService.multipartPost(
        '/audio/transcribe',
        fileBytes: wavData,
        filename: 'recording.wav',
        fields: {
          'model': 'whisper-large-v3',
          'language': 'en',
        },
      );

      final rawText = transcriptionResult['payload']['text'] ?? "";
      print("Backend Transcribed Text: $rawText");

      if (rawText.isEmpty) {
        throw Exception("Transcription result is empty");
      }

      // 2. Detect Macro (Still local for now, but we can move to backend if needed)
      final macroExpansion = await _macroService.findExpansion(rawText);
      if (macroExpansion != null) {
        _statusController.add("Macro Detected! Formatting...");
      } else {
        _statusController.add("Formatting (Gemini)...");
      }

      // 3. Process via Backend (Gemini)
      final processingResult = await _apiService.post('/audio/process', body: {
        'transcript': rawText,
        'macro_context': macroExpansion,
        'mode': 'fast', // or 'smart'
      });

      final formattedText = processingResult['payload']['text'] ?? rawText;
      _statusController.add("Saving...");

      // Broadcast to Desktop UI
      _textStreamController.add(formattedText);
      
      // Auto-save to InboxService
      try {
          final inbox = InboxService();
          await inbox.addNote(formattedText, patientName: "Untitled", summary: "Audio Note");
          print("✅ Automatically saved note to inbox");
      } catch (saveError) {
          print("❌ Failed to auto-save to inbox: $saveError");
      }

      _statusController.add("Ready");

      // 🚀 SEND TO MOBILE CLIENT
      if (client != null) {
         client.sink.add("TRANSCRIPT:$formattedText");
      } else {
         for (var c in _clients) c.sink.add("TRANSCRIPT:$formattedText");
      }

      // Clear buffer
      _audioBuffer.clear();
    } catch (e) {
      print("Error processing WAV: $e");
      _statusController.add("Error: $e");
      client?.sink.add("ERROR:$e");
    }
  }

  Future<void> processAudio(WebSocketChannel client) async {
    if (_audioBuffer.isEmpty) return;

    try {
      // Convert raw PCM to WAV
      Uint8List audioData;
      String filename = 'recording.wav';

      if (_audioBuffer.length > 12 &&
          _audioBuffer[4] == 0x66 && 
          _audioBuffer[5] == 0x74 && 
          _audioBuffer[6] == 0x79 && 
          _audioBuffer[7] == 0x70) {
        print("M4A/AAC Header detected.");
        audioData = Uint8List.fromList(_audioBuffer);
        filename = 'recording.m4a';
      }
      else if (_audioBuffer.length > 44 &&
          _audioBuffer[0] == 0x52 && 
          _audioBuffer[1] == 0x49 && 
          _audioBuffer[2] == 0x46 && 
          _audioBuffer[3] == 0x46) {
        print("WAV Header detected.");
        audioData = Uint8List.fromList(_audioBuffer);
      } else {
        print("Raw PCM detected (assuming), adding WAV header.");
        audioData =
            WavUtils.addWavHeader(Uint8List.fromList(_audioBuffer), 16000, 1);
      }

      _statusController.add("Transcribing...");

      // 1. Transcribe via Backend
      final transcriptionResult = await _apiService.multipartPost(
        '/audio/transcribe',
        fileBytes: audioData,
        filename: filename,
      );

      final rawText = transcriptionResult['payload']['text'] ?? "";
      print("Backend Transcribed Text: $rawText");

      // 2. Detect Macro
      final macroExpansion = await _macroService.findExpansion(rawText);
      if (macroExpansion != null) {
        _statusController.add("Macro Detected! Formatting...");
      } else {
        _statusController.add("Formatting (Gemini)...");
      }

      // 3. Process via Backend
      final processingResult = await _apiService.post('/audio/process', body: {
        'transcript': rawText,
        'macro_context': macroExpansion,
      });

      final formattedText = processingResult['payload']['text'] ?? rawText;
      
      // Broadcast to Desktop UI
      _textStreamController.add(formattedText);
      _statusController.add("Ready");

      // 🚀 SEND TO MOBILE CLIENT
      client.sink.add("TRANSCRIPT:$formattedText");

      // Clear buffer
      _audioBuffer.clear();
    } catch (e) {
      print("Processing Error: $e");
      _statusController.add("Error: $e");
      client.sink.add("ABORTED:$e");
    }
  }

  Future<void> stopServer() async {
    for (var client in _clients) {
      client.sink.close();
    }
    await _server?.close(force: true);
    _statusController.add("Server Stopped");
  }

  // Helper to get local IP for QR Code
  static Future<String> getLocalIpAddress() async {
    final interfaces =
        await NetworkInterface.list(type: InternetAddressType.IPv4);
    try {
      // Try to find a non-loopback address, preferably Wi-Fi
      final interface = interfaces.firstWhere(
        (i) =>
            i.name.toLowerCase().contains('wi-fi') ||
            i.name.toLowerCase().contains('wlan') ||
            i.name.toLowerCase().contains('en0'),
        orElse: () => interfaces.first,
      );
      return interface.addresses.first.address;
    } catch (e) {
      return "127.0.0.1";
    }
  }
}
