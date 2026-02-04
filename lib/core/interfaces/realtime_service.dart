import 'base_service.dart';

/// Real-time communication service interface
abstract class RealtimeService extends BaseService {
  /// Connect to WebSocket server
  Future<void> connect();
  
  /// Disconnect from WebSocket server
  Future<void> disconnect();
  
  /// Check if connected
  bool get isConnected;
  
  /// Watch for real-time events
  Stream<RealtimeEvent> watchEvents();
  
  /// Subscribe to channel
  Future<void> subscribeToChannel(String channel);
  
  /// Unsubscribe from channel
  Future<void> unsubscribeFromChannel(String channel);
  
  /// Send message to channel
  Future<void> sendMessage(String channel, Map<String, dynamic> message);
  
  /// Get connection status
  Stream<ConnectionStatus> watchConnectionStatus();
  
  /// Get subscribed channels
  List<String> getSubscribedChannels();
}

/// Real-time event
class RealtimeEvent {
  final String type;
  final String channel;
  final Map<String, dynamic> data;
  final DateTime timestamp;
  final String? userId;
  
  const RealtimeEvent({
    required this.type,
    required this.channel,
    required this.data,
    required this.timestamp,
    this.userId,
  });
  
  factory RealtimeEvent.fromJson(Map<String, dynamic> json) {
    return RealtimeEvent(
      type: json['type'] ?? '',
      channel: json['channel'] ?? '',
      data: json['data'] ?? {},
      timestamp: json['timestamp'] != null 
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
      userId: json['user_id'],
    );
  }
}

/// Connection status
enum ConnectionStatus {
  disconnected,
  connecting,
  connected,
  reconnecting,
  failed
}

/// WebSocket connection configuration
class WebSocketConfig {
  final String url;
  final String? token;
  final Duration heartbeatInterval;
  final Duration reconnectInterval;
  final int maxReconnectAttempts;
  final Map<String, String> headers;
  
  const WebSocketConfig({
    required this.url,
    this.token,
    this.heartbeatInterval = const Duration(seconds: 30),
    this.reconnectInterval = const Duration(seconds: 5),
    this.maxReconnectAttempts = 5,
    this.headers = const {},
  });
}