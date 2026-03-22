import 'package:flutter_dotenv/flutter_dotenv.dart';

/// API Configuration for ScribeFlow Backend Integration
class ApiConfig {
  // Base URL for the Laravel backend - strictly from .env
  static String get baseUrl {
    final url = dotenv.env['API_BASE_URL'];
    if (url == null || url.isEmpty) {
      // In production/testing, if env is missing, it's a fatal configuration error
      // but we return empty to let the caller handle it or fail naturally.
      // Strict commitment: No hardcoded fallback.
      return '';
    }
    return url;
  }

  // API Endpoints
  static const String macrosEndpoint = '/macros';
  static const String inboxNotesEndpoint = '/inbox-notes';
  static const String usersEndpoint = '/users';
  static const String authEndpoint = '/auth';

  // Request timeout in milliseconds
  static const int requestTimeout = 30000;

  // Supported audio formats for upload
  static const List<String> supportedAudioFormats = [
    'mp3',
    'wav',
    'm4a',
    'flac',
    'aac',
    'ogg',
    'webm',
    'mp4',
    'mpeg',
    'mpga'
  ];

  // File size limits
  static const int maxAudioFileSize = 25 * 1024 * 1024; // 25MB
  static const int minAudioFileSize = 1024; // 1KB

  // Cache settings
  static const Duration defaultCacheDuration = Duration(minutes: 30);
  static const Duration macroCacheDuration = Duration(hours: 2);
  static const Duration settingsCacheDuration = Duration(hours: 24);

  // Polling intervals
  static const Duration transcriptionPollingInterval = Duration(seconds: 2);
  static const Duration syncInterval = Duration(minutes: 5);

  // Headers
  static Map<String, String> get defaultHeaders => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  static Map<String, String> getAuthHeaders(String token) => {
        ...defaultHeaders,
        'Authorization': 'Bearer $token',
      };
}
