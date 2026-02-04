import 'dart:async';
import 'dart:developer' as developer;
import 'app_error.dart';
import '../../services/api_service.dart';

/// Error handling strategy
enum ErrorStrategy {
  retry,
  fallback,
  notify,
  ignore,
  crash
}

/// Error recovery configuration
class ErrorRecoveryConfig {
  final int maxRetries;
  final Duration retryDelay;
  final Duration maxRetryDelay;
  final double backoffMultiplier;
  final ErrorStrategy strategy;
  
  const ErrorRecoveryConfig({
    this.maxRetries = 3,
    this.retryDelay = const Duration(seconds: 1),
    this.maxRetryDelay = const Duration(seconds: 30),
    this.backoffMultiplier = 2.0,
    this.strategy = ErrorStrategy.retry,
  });
}

/// Global error handler
class ErrorHandler {
  static final ErrorHandler _instance = ErrorHandler._internal();
  factory ErrorHandler() => _instance;
  ErrorHandler._internal();
  
  final StreamController<AppError> _errorController = StreamController<AppError>.broadcast();
  
  /// Stream of errors for UI to listen to
  Stream<AppError> get errorStream => _errorController.stream;
  
  /// Handle error with recovery strategy
  Future<T> handleError<T>(
    Future<T> Function() operation,
    ErrorRecoveryConfig config,
  ) async {
    int attempts = 0;
    Duration currentDelay = config.retryDelay;
    
    while (attempts < config.maxRetries) {
      try {
        return await operation();
      } catch (error) {
        attempts++;
        final appError = _convertToAppError(error);
        
        // Log error
        _logError(appError, attempts);
        
        // Emit error to stream
        _errorController.add(appError);
        
        // Check if we should retry
        if (attempts >= config.maxRetries || !_shouldRetry(appError, config)) {
          throw appError;
        }
        
        // Wait before retry
        await Future.delayed(currentDelay);
        
        // Increase delay for next attempt
        currentDelay = Duration(
          milliseconds: (currentDelay.inMilliseconds * config.backoffMultiplier).round(),
        );
        
        if (currentDelay > config.maxRetryDelay) {
          currentDelay = config.maxRetryDelay;
        }
      }
    }
    
    throw StateError('This should never be reached');
  }
  
  /// Handle error without retry
  void reportError(dynamic error, [StackTrace? stackTrace]) {
    final appError = _convertToAppError(error);
    _logError(appError, 1);
    _errorController.add(appError);
  }
  
  /// Convert any error to AppError (public for testing)
  AppError convertToAppError(dynamic error) {
    return _convertToAppError(error);
  }
  
  /// Convert any error to AppError
  AppError _convertToAppError(dynamic error) {
    if (error is AppError) {
      return error;
    }
    
    if (error is ApiException) {
      return NetworkError(
        error.message,
        statusCode: error.statusCode,
        code: _getErrorCode(error),
        context: {'errors': error.errors},
      );
    }
    
    if (error is TimeoutException) {
      return NetworkError(
        'Request timeout',
        code: 'timeout',
        context: {'timeout': error.duration?.inSeconds},
      );
    }
    
    if (error.toString().contains('SocketException') ||
        error.toString().contains('Failed host lookup')) {
      return NetworkError(
        'No internet connection',
        code: 'no_connection',
      );
    }
    
    return UnknownError(
      error.toString(),
      code: 'unknown',
      context: {'original_error': error.runtimeType.toString()},
    );
  }
  
  /// Get error code from ApiException
  String _getErrorCode(ApiException error) {
    if (error.isUnauthorized) return 'unauthorized';
    if (error.isValidationError) return 'validation';
    if (error.isServerError) return 'server_error';
    if (error.isNotFound) return 'not_found';
    return 'api_error';
  }
  
  /// Check if error should be retried
  bool _shouldRetry(AppError error, ErrorRecoveryConfig config) {
    if (config.strategy != ErrorStrategy.retry) {
      return false;
    }
    
    // Don't retry validation errors
    if (error is ValidationError) {
      return false;
    }
    
    // Don't retry authentication errors
    if (error is AuthError) {
      return false;
    }
    
    // Retry network errors except client errors
    if (error is NetworkError) {
      return !error.isClientError;
    }
    
    return true;
  }
  
  /// Log error
  void _logError(AppError error, int attempt) {
    developer.log(
      'Error (attempt $attempt): ${error.message}',
      name: 'ErrorHandler',
      error: error,
      level: _getLogLevel(error),
    );
  }
  
  /// Get log level for error
  int _getLogLevel(AppError error) {
    if (error is NetworkError && error.isServerError) {
      return 1000; // Severe
    }
    if (error is AuthError) {
      return 900; // Warning
    }
    return 800; // Info
  }
  
  /// Dispose resources
  void dispose() {
    _errorController.close();
  }
}

/// Extension for easy error handling
extension ErrorHandlerExtension<T> on Future<T> {
  /// Handle errors with default config
  Future<T> handleErrors() {
    return ErrorHandler().handleError(
      () => this,
      const ErrorRecoveryConfig(),
    );
  }
  
  /// Handle errors with custom config
  Future<T> handleErrorsWith(ErrorRecoveryConfig config) {
    return ErrorHandler().handleError(
      () => this,
      config,
    );
  }
}