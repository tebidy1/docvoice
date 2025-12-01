import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../utils/wav_utils.dart';
import 'groq_service.dart';
import 'gemini_service.dart';
import 'macro_service.dart';

class ConnectivityServer {
  HttpServer? _server;
  final List<WebSocketChannel> _clients = [];
  
  // Audio Buffer
  List<int> _audioBuffer = [];
  bool _isReceivingAudio = false;
  
  // Services
  late GroqService _groqService;
  late GeminiService _geminiService;
  final MacroService _macroService = MacroService();
  
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
    // Initialize Services
    _groqService = GroqService(apiKey: dotenv.env['GROQ_API_KEY'] ?? "");
    _geminiService = GeminiService(apiKey: dotenv.env['GEMINI_API_KEY'] ?? "");
    _macroService.init();
  }

  Future<void> startServer({int port = 8080}) async {
    // Reload env to be sure
    await dotenv.load();
    _groqService = GroqService(apiKey: dotenv.env['GROQ_API_KEY'] ?? "");
    _geminiService = GeminiService(apiKey: dotenv.env['GEMINI_API_KEY'] ?? "");
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
              await processAudio();
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

  /// Processes a complete WAV file directly (used for Desktop file-based recording)
  Future<void> transcribeWav(Uint8List wavData) async {
    _statusController.add("Transcribing...");
    
    try {
      // Send to Groq
      final rawText = await _groqService.transcribe(wavData);
      print("Groq Transcribed Text: $rawText");
      
      // Check for Macros
      final macroExpansion = await _macroService.findExpansion(rawText);
      if (macroExpansion != null) {
        _statusController.add("Macro Found: $macroExpansion");
      } else {
        _statusController.add("Formatting (Gemini)...");
      }

      // Send to Gemini (DISABLED FOR TESTING)
      // final formattedText = await _geminiService.formatText(rawText, macroContext: macroExpansion);
      final formattedText = rawText; // Direct pass-through
      
      // Broadcast text
      _textStreamController.add(formattedText);
      _statusController.add("Ready (Groq Only)");
      
    } catch (e) {
      print("Error processing WAV: $e");
      _statusController.add("Error: $e");
    }
  }

  Future<void> processAudio() async {
    if (_audioBuffer.isEmpty) return;
    
    try {
      // Convert raw PCM to WAV
      // Assuming 16kHz 1 channel 16bit PCM from mobile
      // Check if we already have a RIFF header
      Uint8List wavData;
      if (_audioBuffer.length > 44 && 
          _audioBuffer[0] == 0x52 && // R
          _audioBuffer[1] == 0x49 && // I
          _audioBuffer[2] == 0x46 && // F
          _audioBuffer[3] == 0x46) { // F
        print("WAV Header detected, skipping manual header addition.");
        wavData = Uint8List.fromList(_audioBuffer);
      } else {
        print("No WAV Header detected, adding one.");
        wavData = WavUtils.addWavHeader(Uint8List.fromList(_audioBuffer), 16000, 1);
      }
      
      // Send to Groq
      final rawText = await _groqService.transcribe(wavData);
      print("Groq Transcribed Text: $rawText");
      
      // Check for Macros
      final macroExpansion = await _macroService.findExpansion(rawText);
      if (macroExpansion != null) {
        _statusController.add("Macro Detected! Formatting...");
      } else {
        _statusController.add("Formatting (Gemini)...");
      }

      // Send to Gemini
      final formattedText = await _geminiService.formatText(rawText, macroContext: macroExpansion);
      // final formattedText = rawText; // Direct pass-through
      
      // Broadcast text
      _textStreamController.add(formattedText);
      _statusController.add("Ready (Groq Only)");
      
      // Clear buffer
      _audioBuffer.clear();
    } catch (e) {
      print("Processing Error: $e");
      _statusController.add("Error: $e");
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
    final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
    try {
      // Try to find a non-loopback address, preferably Wi-Fi
      final interface = interfaces.firstWhere(
        (i) => i.name.toLowerCase().contains('wi-fi') || i.name.toLowerCase().contains('wlan') || i.name.toLowerCase().contains('en0'),
        orElse: () => interfaces.first,
      );
      return interface.addresses.first.address;
    } catch (e) {
      return "127.0.0.1";
    }
  }
}
