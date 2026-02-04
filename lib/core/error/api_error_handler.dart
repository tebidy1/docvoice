/// API error handler for ScribeFlow backend integration
/// 
/// This file handles the categorization and processing of API errors,
/// converting Dio errors into appropriate exception types with user-friendly messages.

import 'dart:developer' as developer;
import 'package:dio/dio.dart';
import 'api_exceptions.dart';

/// API error handler for processing and categorizing errors
class ApiErrorHandler {
  /// Handle Dio errors and convert them to appropriate exceptions
  static ApiException handleDioError(DioException error) {
    developer.log(
      'Handling Dio error: ${error.type} - ${error.message}',
      name: 'ApiErrorHandler',
    );
    
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
        return const TimeoutException(
          'Connection timeout. Please check your internet connection and try again.',
          statusCode: 408,
        );
        
      case DioExceptionType.sendTimeout:
        return const TimeoutException(
          'Request timeout. The server is taking too long to respond.',
          statusCode: 408,
        );
        
      case DioExceptionType.receiveTimeout:
        return const TimeoutException(
          'Response timeout. Please try again.',
          statusCode: 408,
        );
        
      case DioExceptionType.badResponse:
        return _handleResponseError(error.response!);
        
      case DioExceptionType.cancel:
        return const RequestCancelledException(
          'Request was cancelled.',
        );
        
      case DioExceptionType.connectionError:
        return const NetworkException(
          'Network connection error. Please check your internet connection.',
        );
        
      case DioExceptionType.badCertificate:
        return const NetworkException(
          'SSL certificate error. Please check your connection security.',
        );
        
      case DioExceptionType.unknown:
      default:
        return NetworkException(
          'An unexpected error occurred: ${error.message ?? 'Unknown error'}',
        );
    }
  }
  
  /// Handle HTTP response errors based on status codes
  static ApiException _handleResponseError(Response response) {
    final statusCode = response.statusCode ?? 0;
    final data = response.data;
    
    developer.log(
      'Handling response error: $statusCode - $data',
      name: 'ApiErrorHandler',
    );
    
    // Extract error message and details from response
    String message = 'An error occurred';
    List<String>? errors;
    Map<String, List<String>>? fieldErrors;
    Map<String, dynamic>? details;
    
    if (data is Map<String, dynamic>) {
      message = data['message']?.toString() ?? message;
      
      if (data['errors'] is List) {
        errors = List<String>.from(data['errors']);
      } else if (data['errors'] is Map) {
        // Laravel validation errors format
        final errorMap = data['errors'] as Map<String, dynamic>;
        fieldErrors = errorMap.map(
          (key, value) => MapEntry(
            key,
            value is List 
                ? List<String>.from(value) 
                : [value.toString()],
          ),
        );
        
        // Create a general error list from field errors
        errors = fieldErrors.values.expand((list) => list).toList();
      }
      
      details = data;
    }
    
    switch (statusCode) {
      case 400:
        return ValidationException(
          message.isEmpty ? 'Bad request. Please check your input.' : message,
          fieldErrors: fieldErrors,
          statusCode: statusCode,
          details: details,
        );
        
      case 401:
        return AuthenticationException(
          message.isEmpty ? 'Authentication failed. Please login again.' : message,
          statusCode: statusCode,
          details: details,
        );
        
      case 403:
        return AuthorizationException(
          message.isEmpty ? 'You do not have permission to perform this action.' : message,
          statusCode: statusCode,
          details: details,
        );
        
      case 404:
        return ApiException(
          message.isEmpty ? 'The requested resource was not found.' : message,
          statusCode: statusCode,
          details: details,
        );
        
      case 409:
        return SyncException(
          message.isEmpty ? 'Data conflict occurred. Please refresh and try again.' : message,
          statusCode: statusCode,
          details: details,
        );
        
      case 422:
        return ValidationException(
          message.isEmpty ? 'Validation failed. Please check your input.' : message,
          fieldErrors: fieldErrors,
          statusCode: statusCode,
          details: details,
        );
        
      case 429:
        DateTime? retryAfter;
        final retryAfterHeader = response.headers.value('retry-after');
        if (retryAfterHeader != null) {
          final retryAfterSeconds = int.tryParse(retryAfterHeader);
          if (retryAfterSeconds != null) {
            retryAfter = DateTime.now().add(Duration(seconds: retryAfterSeconds));
          }
        }
        
        return RateLimitException(
          message.isEmpty ? 'Too many requests. Please try again later.' : message,
          retryAfter: retryAfter,
          statusCode: statusCode,
          details: details,
        );
        
      case 500:
        return ServerException(
          message.isEmpty ? 'Internal server error. Please try again later.' : message,
          statusCode: statusCode,
          details: details,
        );
        
      case 502:
        return ServerException(
          message.isEmpty ? 'Bad gateway. The server is temporarily unavailable.' : message,
          statusCode: statusCode,
          details: details,
        );
        
      case 503:
        return ServerException(
          message.isEmpty ? 'Service unavailable. Please try again later.' : message,
          statusCode: statusCode,
          details: details,
        );
        
      case 504:
        return TimeoutException(
          message.isEmpty ? 'Gateway timeout. Please try again.' : message,
          statusCode: statusCode,
          details: details,
        );
        
      default:
        if (statusCode >= 500) {
          return ServerException(
            message.isEmpty ? 'Server error occurred. Please try again later.' : message,
            statusCode: statusCode,
            details: details,
          );
        } else if (statusCode >= 400) {
          return ApiException(
            message.isEmpty ? 'Client error occurred. Please check your request.' : message,
            statusCode: statusCode,
            details: details,
          );
        } else {
          return ApiException(
            message.isEmpty ? 'An unexpected error occurred.' : message,
            statusCode: statusCode,
            details: details,
          );
        }
    }
  }
  
  /// Get user-friendly error message from exception
  static String getUserFriendlyMessage(ApiException exception) {
    switch (exception.runtimeType) {
      case NetworkException:
        return 'Please check your internet connection and try again.';
        
      case AuthenticationException:
        return 'Please login again to continue.';
        
      case AuthorizationException:
        return 'You don\'t have permission to perform this action.';
        
      case ValidationException:
        final validationEx = exception as ValidationException;
        if (validationEx.fieldErrors?.isNotEmpty == true) {
          final firstError = validationEx.fieldErrors!.values.first.first;
          return firstError;
        }
        return exception.message;
        
      case TimeoutException:
        return 'The request timed out. Please try again.';
        
      case RateLimitException:
        return 'Too many requests. Please wait a moment and try again.';
        
      case ServerException:
        return 'Server error. Please try again later.';
        
      case FileUploadException:
        return 'File upload failed. Please check the file and try again.';
        
      case SyncException:
        return 'Data synchronization failed. Please refresh and try again.';
        
      default:
        return exception.message.isNotEmpty 
            ? exception.message 
            : 'An unexpected error occurred.';
    }
  }
  
  /// Check if error is retryable
  static bool isRetryable(ApiException exception) {
    switch (exception.runtimeType) {
      case NetworkException:
      case TimeoutException:
      case ServerException:
        return true;
        
      case RateLimitException:
        return true; // Can retry after delay
        
      case AuthenticationException:
        return false; // Need to re-authenticate
        
      case AuthorizationException:
      case ValidationException:
        return false; // User action required
        
      default:
        // For unknown errors, allow retry but with caution
        return exception.statusCode == null || exception.statusCode! >= 500;
    }
  }
  
  /// Get retry delay for retryable errors
  static Duration getRetryDelay(ApiException exception, int attemptNumber) {
    if (exception is RateLimitException && exception.retryAfter != null) {
      final delay = exception.retryAfter!.difference(DateTime.now());
      return delay.isNegative ? Duration.zero : delay;
    }
    
    // Exponential backoff: 1s, 2s, 4s, 8s, max 30s
    final baseDelay = Duration(seconds: 1 << (attemptNumber - 1));
    const maxDelay = Duration(seconds: 30);
    
    return baseDelay > maxDelay ? maxDelay : baseDelay;
  }
  
  /// Log error details for debugging
  static void logError(ApiException exception, {String? context}) {
    final contextStr = context != null ? '[$context] ' : '';
    developer.log(
      '${contextStr}API Error: ${exception.runtimeType} - ${exception.message}',
      name: 'ApiErrorHandler',
      error: exception,
    );
    
    if (exception.details != null) {
      developer.log(
        '${contextStr}Error details: ${exception.details}',
        name: 'ApiErrorHandler',
      );
    }
  }
}