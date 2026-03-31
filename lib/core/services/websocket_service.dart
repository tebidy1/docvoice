import 'dart:async';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'package:flutter/foundation.dart';

class WebSocketService {
  WebSocketChannel? _channel;
  final StreamController<dynamic> _streamController = StreamController<dynamic>.broadcast();
  bool _isConnected = false;
  
  Stream<dynamic> get messages => _streamController.stream;
  bool get isConnected => _isConnected;

  Future<void> connect(String ipAddress, String port) async {
    final uri = Uri.parse('ws://$ipAddress:$port/ws'); // Endpoint assumption
    debugPrint("Connecting to $uri...");

    try {
      _channel = WebSocketChannel.connect(uri);
      _isConnected = true;
      
      _channel!.stream.listen(
        (message) {
          debugPrint("WS Message: $message");
          _streamController.add(message);
        },
        onDone: () {
          debugPrint("WS Disconnected");
          _isConnected = false;
        },
        onError: (error) {
          debugPrint("WS Error: $error");
          _isConnected = false;
        },
      );
    } catch (e) {
      debugPrint("WS Connection Failed: $e");
      _isConnected = false;
      rethrow;
    }
  }

  void sendMessage(dynamic message) {
    if (_isConnected && _channel != null) {
      _channel!.sink.add(message);
    } else {
      debugPrint("Cannot send message: WebSocket not connected");
    }
  }

  Future<void> disconnect() async {
    if (_channel != null) {
      await _channel!.sink.close(status.goingAway);
      _isConnected = false;
    }
  }
}
