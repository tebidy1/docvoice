import 'dart:async';

abstract class IWebSocketService {
  Stream<dynamic> get messages;
  bool get isConnected;

  Future<void> connect(String ipAddress, String port);
  void sendMessage(dynamic message);
  Future<void> disconnect();
}
