import 'dart:async';
import 'dart:typed_data';
import 'package:web_socket_channel/web_socket_channel.dart';

class ConnectivityClient {
  WebSocketChannel? _channel;
  
  final _statusController = StreamController<String>.broadcast();
  Stream<String> get statusStream => _statusController.stream;

  bool get isConnected => _channel != null;

  Future<void> connect(String ip, {int port = 8080}) async {
    final uri = Uri.parse('ws://$ip:$port');
    try {
      _channel = WebSocketChannel.connect(uri);
      await _channel!.ready;
      _statusController.add("Connected");
      print("Connected to $uri");
      
      _channel!.stream.listen(
        (message) {
          print("Received from server: $message");
        },
        onDone: () {
          _statusController.add("Disconnected");
          _channel = null;
        },
        onError: (error) {
          _statusController.add("Error: $error");
          _channel = null;
        },
      );
    } catch (e) {
      _statusController.add("Connection Failed: $e");
      print("Connection failed: $e");
      rethrow;
    }
  }

  void startStreaming() {
    if (_channel != null) {
      _channel!.sink.add("START_RECORDING");
    }
  }

  void sendAudioChunk(Uint8List data) {
    if (_channel != null) {
      _channel!.sink.add(data);
    }
  }

  void stopStreaming() {
    if (_channel != null) {
      _channel!.sink.add("STOP_RECORDING");
    }
  }

  void disconnect() {
    _channel?.sink.close();
    _channel = null;
    _statusController.add("Disconnected");
  }
}
