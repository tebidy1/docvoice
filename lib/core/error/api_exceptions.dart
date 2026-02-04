/// API exception classes for ScribeFlow backend integration
/// 
/// This file contains all the exception classes related to API communication,
/// including network errors, authentication errors, and validation errors.

/// Base API exception class
abstract class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final Map<String, dynamic>? details;
  
  const ApiException(this.message, {this.statusCode, this.details});
  
  @override
  String toString() => 'ApiException: $message';
}

/// Network-related exceptions
class NetworkException extends ApiException {
  const NetworkException(String message, {int? statusCode, Map<String, dynamic>? details})
      : super(message, statusCode: statusCode, details: details);
  
  @override
  String toString() => 'NetworkException: $message';
}

/// Authentication-related exceptions
class AuthenticationException extends ApiException {
  const AuthenticationException(String message, {int? statusCode, Map<String, dynamic>? details})
      : super(message, statusCode: statusCode, details: details);
  
  @override
  String toString() => 'AuthenticationException: $message';
}

/// Authorization-related exceptions
class AuthorizationException extends ApiException {
  const AuthorizationException(String message, {int? statusCode, Map<String, dynamic>? details})
      : super(message, statusCode: statusCode, details: details);
  
  @override
  String toString() => 'AuthorizationException: $message';
}

/// Validation-related exceptions
class ValidationException extends ApiException {
  final Map<String, List<String>>? fieldErrors;
  
  const ValidationException(
    String message, {
    this.fieldErrors,
    int? statusCode,
    Map<String, dynamic>? details,
  }) : super(message, statusCode: statusCode, details: details);
  
  /// Get errors for a specific field
  List<String> getFieldErrors(String field) {
    return fieldErrors?[field] ?? [];
  }
  
  /// Check if a specific field has errors
  bool hasFieldErrors(String field) {
    return fieldErrors?.containsKey(field) ?? false;
  }
  
  /// Get all field names with errors
  List<String> get fieldsWithErrors {
    return fieldErrors?.keys.toList() ?? [];
  }
  
  @override
  String toString() => 'ValidationException: $message';
}

/// Server-related exceptions
class ServerException extends ApiException {
  const ServerException(String message, {int? statusCode, Map<String, dynamic>? details})
      : super(message, statusCode: statusCode, details: details);
  
  @override
  String toString() => 'ServerException: $message';
}

/// Request cancellation exception
class RequestCancelledException extends ApiException {
  const RequestCancelledException(String message, {int? statusCode, Map<String, dynamic>? details})
      : super(message, statusCode: statusCode, details: details);
  
  @override
  String toString() => 'RequestCancelledException: $message';
}

/// Timeout exception
class TimeoutException extends ApiException {
  const TimeoutException(String message, {int? statusCode, Map<String, dynamic>? details})
      : super(message, statusCode: statusCode, details: details);
  
  @override
  String toString() => 'TimeoutException: $message';
}

/// Rate limiting exception
class RateLimitException extends ApiException {
  final DateTime? retryAfter;
  
  const RateLimitException(
    String message, {
    this.retryAfter,
    int? statusCode,
    Map<String, dynamic>? details,
  }) : super(message, statusCode: statusCode, details: details);
  
  @override
  String toString() => 'RateLimitException: $message';
}

/// File upload exception
class FileUploadException extends ApiException {
  final String? fileName;
  final int? fileSize;
  
  const FileUploadException(
    String message, {
    this.fileName,
    this.fileSize,
    int? statusCode,
    Map<String, dynamic>? details,
  }) : super(message, statusCode: statusCode, details: details);
  
  @override
  String toString() => 'FileUploadException: $message';
}

/// Data synchronization exception
class SyncException extends ApiException {
  final String? entityType;
  final String? entityId;
  final String? conflictType;
  
  const SyncException(
    String message, {
    this.entityType,
    this.entityId,
    this.conflictType,
    int? statusCode,
    Map<String, dynamic>? details,
  }) : super(message, statusCode: statusCode, details: details);
  
  @override
  String toString() => 'SyncException: $message';
}

/// Cache-related exception
class CacheException extends ApiException {
  final String? cacheKey;
  final String? operation;
  
  const CacheException(
    String message, {
    this.cacheKey,
    this.operation,
    int? statusCode,
    Map<String, dynamic>? details,
  }) : super(message, statusCode: statusCode, details: details);
  
  @override
  String toString() => 'CacheException: $message';
}

/// Configuration exception
class ConfigurationException extends ApiException {
  final String? configKey;
  
  const ConfigurationException(
    String message, {
    this.configKey,
    int? statusCode,
    Map<String, dynamic>? details,
  }) : super(message, statusCode: statusCode, details: details);
  
  @override
  String toString() => 'ConfigurationException: $message';
}