import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../utils/wav_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scribe_brain/scribe_brain.dart';
import '../models/inbox_note.dart';
import 'macro_service.dart';
import 'inbox_service.dart';

class ConnectivityServer {
  HttpServer? _server;
  final List<WebSocketChannel> _clients = [];
  
  // Audio Buffer
  List<int> _audioBuffer = [];
  bool _isReceivingAudio = false;
  
  // Services
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
                 await inbox.updateStatus(newId, InboxStatus.processed);
                 
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
  Future<void> transcribeWav(Uint8List wavData, {WebSocketChannel? client}) async {
    _statusController.add("Transcribing...");
    
    try {
      // 1. Setup Engine & Config
      // 1. Setup Engine & Config
      final prefs = await SharedPreferences.getInstance();
      final customGeminiKey = prefs.getString('gemini_api_key');
      final engine = ProcessingEngine(
        groqApiKey: dotenv.env['GROQ_API_KEY'] ?? "",
        geminiApiKey: (customGeminiKey != null && customGeminiKey.isNotEmpty) 
            ? customGeminiKey 
            : (dotenv.env['GEMINI_API_KEY'] ?? ""),
      );
      
      final groqPref = prefs.getString('groq_model_pref') ?? GroqModel.precise.modelId;
      final config = ProcessingConfig(
        groqModel: GroqModel.values.firstWhere((e) => e.modelId == groqPref, orElse: () => GroqModel.precise),
        geminiMode: GeminiMode.fast,
        userPreferences: {}
      );

      // 2. Transcribe
      final transcriptResult = await engine.processRequest(
        audioBytes: wavData, 
        config: config,
        skipAi: true
      );
      final rawText = transcriptResult.rawTranscript;
      print("Groq Transcribed Text: $rawText");
      
      // 3. Detect Macro
      final macroExpansion = await _macroService.findExpansion(rawText);
      if (macroExpansion != null) {
        _statusController.add("Macro Found: $macroExpansion");
      } else {
        _statusController.add("Formatting (Gemini)...");
      }

      // 4. Format
      final finalResult = await engine.processRequest(
        rawTranscript: rawText,
        config: config,
        macroContent: macroExpansion
      );
      final formattedText = finalResult.formattedText;
      
      // Broadcast to Desktop UI
      _textStreamController.add(formattedText);
      
      // Send to Mobile Client
      if (client != null) {
        client.sink.add("TRANSCRIPT:$formattedText");
      } else {
        // Fallback: Broadcast to all
        for (var c in _clients) {
          c.sink.add("TRANSCRIPT:$formattedText");
        }
      }

      _statusController.add("Ready (Sent to Mobile)");
      
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
      // Assuming 16kHz 1 channel 16bit PCM from mobile
      // Check if we already have a RIFF header
      Uint8List audioData;
      String filename = 'recording.wav';

      // Check for M4A/MP4 Header (ftyp)
      // Usually starts with ....ftyp or 00 00 00 18 66 74 79 70
      if (_audioBuffer.length > 12 && 
          _audioBuffer[4] == 0x66 && // f
          _audioBuffer[5] == 0x74 && // t
          _audioBuffer[6] == 0x79 && // y
          _audioBuffer[7] == 0x70) { // p
        print("M4A/AAC Header detected.");
        audioData = Uint8List.fromList(_audioBuffer);
        filename = 'recording.m4a';
      } 
      // Check for RIFF (WAV)
      else if (_audioBuffer.length > 44 && 
          _audioBuffer[0] == 0x52 && // R
          _audioBuffer[1] == 0x49 && // I
          _audioBuffer[2] == 0x46 && // F
          _audioBuffer[3] == 0x46) { // F
        print("WAV Header detected.");
        audioData = Uint8List.fromList(_audioBuffer);
      } else {
        print("Raw PCM detected (assuming), adding WAV header.");
        audioData = WavUtils.addWavHeader(Uint8List.fromList(_audioBuffer), 16000, 1);
      }
      
      // 1. Setup Engine & Config
      // 1. Setup Engine & Config
      final prefs = await SharedPreferences.getInstance();
      final customGeminiKey = prefs.getString('gemini_api_key');
      final engine = ProcessingEngine(
        groqApiKey: dotenv.env['GROQ_API_KEY'] ?? "",
        geminiApiKey: (customGeminiKey != null && customGeminiKey.isNotEmpty) 
            ? customGeminiKey 
            : (dotenv.env['GEMINI_API_KEY'] ?? ""),
      );
      
      final groqPref = prefs.getString('groq_model_pref') ?? GroqModel.precise.modelId;
      final config = ProcessingConfig(
        groqModel: GroqModel.values.firstWhere((e) => e.modelId == groqPref, orElse: () => GroqModel.precise),
        geminiMode: GeminiMode.fast, // Desktop usually fast mode (text only)
        userPreferences: {
           // Can pass global prompt here if stored in desktop prefs (ToDo)
        }
      );

      // 2. Transcribe (Skip AI formatting first to allow macro detection)
      final transcriptResult = await engine.processRequest(
        audioBytes: audioData, 
        config: config,
        skipAi: true
      );
      var rawText = transcriptResult.rawTranscript;
      print("Groq Transcribed Text: $rawText");
      
      // 3. Detect Macro
      final macroExpansion = await _macroService.findExpansion(rawText);
      if (macroExpansion != null) {
        _statusController.add("Macro Detected! Formatting...");
      } else {
        _statusController.add("Formatting (Gemini)...");
      }

      // 4. Format with AI
      final finalResult = await engine.processRequest(
        rawTranscript: rawText,
        config: config, 
        macroContent: macroExpansion
      );
      final formattedText = finalResult.formattedText;
      
      // Broadcast to Desktop UI
      _textStreamController.add(formattedText);
      _statusController.add("Ready (Sent to Mobile)");

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
