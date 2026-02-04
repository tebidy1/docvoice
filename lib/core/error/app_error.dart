/// Base class for all application errors
abstract class AppError implements Exception {
  final String message;
  final String? code;
  final Map<String, dynamic>? context;
  final DateTime timestamp;
  
  AppError(
    this.message, {
    this.code,
    this.context,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
  
  @override
  String toString() => 'AppError: $message';
}

/// Network-related errors
class NetworkError extends AppError {
  final int? statusCode;
  
  NetworkError(
    String message, {
    this.statusCode,
    String? code,
    Map<String, dynamic>? context,
  }) : super(message, code: code, context: context);
  
  bool get isTimeout => code == 'timeout';
  bool get isNoConnection => code == 'no_connection';
  bool get isServerError => statusCode != null && statusCode! >= 500;
  bool get isClientError => statusCode != null && statusCode! >= 400 && statusCode! < 500;
}

/// Authentication errors
class AuthError extends AppError {
  AuthError(
    String message, {
    String? code,
    Map<String, dynamic>? context,
  }) : super(message, code: code, context: context);
  
  bool get isUnauthorized => code == 'unauthorized';
  bool get isTokenExpired => code == 'token_expired';
  bool get isInvalidCredentials => code == 'invalid_credentials';
}

/// Validation errors
class ValidationError extends AppError {
  final Map<String, List<String>> fieldErrors;
  
  ValidationError(
    String message,
    this.fieldErrors, {
    String? code,
    Map<String, dynamic>? context,
  }) : super(message, code: code, context: context);
  
  List<String> getFieldErrors(String field) {
    return fieldErrors[field] ?? [];
  }
  
  bool hasFieldError(String field) {
    return fieldErrors.containsKey(field) && fieldErrors[field]!.isNotEmpty;
  }
}

/// Cache-related errors
class CacheError extends AppError {
  CacheError(
    String message, {
    String? code,
    Map<String, dynamic>? context,
  }) : super(message, code: code, context: context);
}

/// Sync-related errors
class SyncError extends AppError {
  final List<String> failedOperations;
  
  SyncError(
    String message,
    this.failedOperations, {
    String? code,
    Map<String, dynamic>? context,
  }) : super(message, code: code, context: context);
}

/// Audio processing errors
class AudioError extends AppError {
  AudioError(
    String message, {
    String? code,
    Map<String, dynamic>? context,
  }) : super(message, code: code, context: context);
  
  bool get isUnsupportedFormat => code == 'unsupported_format';
  bool get isFileTooLarge => code == 'file_too_large';
  bool get isTranscriptionFailed => code == 'transcription_failed';
}

/// WebSocket connection errors
class WebSocketError extends AppError {
  WebSocketError(
    String message, {
    String? code,
    Map<String, dynamic>? context,
  }) : super(message, code: code, context: context);
  
  bool get isConnectionFailed => code == 'connection_failed';
  bool get isReconnectFailed => code == 'reconnect_failed';
}

/// Storage errors
class StorageError extends AppError {
  StorageError(
    String message, {
    String? code,
    Map<String, dynamic>? context,
  }) : super(message, code: code, context: context);
  
  bool get isInsufficientSpace => code == 'insufficient_space';
  bool get isPermissionDenied => code == 'permission_denied';
}

/// Unknown errors
class UnknownError extends AppError {
  UnknownError(
    String message, {
    String? code,
    Map<String, dynamic>? context,
  }) : super(message, code: code, context: context);
}