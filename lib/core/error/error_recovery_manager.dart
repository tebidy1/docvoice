/// Error recovery manager for ScribeFlow backend integration
/// 
/// This file handles error recovery strategies including exponential backoff,
/// retry logic, and user-friendly error handling.

import 'dart:developer' as developer;
import 'dart:math' as math;
import 'api_exceptions.dart';
import 'api_error_handler.dart';

/// Error recovery strategy configuration
class ErrorRecoveryStrategy {
  final int maxAttempts;
  final Duration initialDelay;
  final Duration maxDelay;
  final double backoffMultiplier;
  final bool enableJitter;
  final List<Type> retryableExceptions;
  
  const ErrorRecoveryStrategy({
    this.maxAttempts = 3,
    this.initialDelay = const Duration(seconds: 1),
    this.maxDelay = const Duration(seconds: 30),
    this.backoffMultiplier = 2.0,
    this.enableJitter = true,
    this.retryableExceptions = const [
      NetworkException,
      TimeoutException,
      ServerException,
      RateLimitException,
    ],
  });
  
  /// Calculate delay for a specific attempt
  Duration calculateDelay(int attempt) {
    if (attempt <= 0) return Duration.zero;
    
    // Exponential backoff: initialDelay * (backoffMultiplier ^ (attempt - 1))
    final exponentialDelay = initialDelay.inMilliseconds * 
        math.pow(backoffMultiplier, attempt - 1);
    
    Duration delay = Duration(milliseconds: exponentialDelay.round());
    
    // Cap at max delay
    if (delay > maxDelay) {
      delay = maxDelay;
    }
    
    // Add jitter to prevent thundering herd
    if (enableJitter) {
      final jitterMs = (delay.inMilliseconds * 0.1 * math.Random().nextDouble()).round();
      delay = Duration(milliseconds: delay.inMilliseconds + jitterMs);
    }
    
    return delay;
  }
  
  /// Check if exception is retryable
  bool isRetryable(Exception exception) {
    if (exception is ApiException) {
      return ApiErrorHandler.isRetryable(exception);
    }
    
    return retryableExceptions.contains(exception.runtimeType);
  }
}

/// Predefined recovery strategies
class ErrorRecoveryStrategies {
  /// Default strategy for most API calls
  static const ErrorRecoveryStrategy defaultStrategy = ErrorRecoveryStrategy();
  
  /// Aggressive strategy for critical operations
  static const ErrorRecoveryStrategy aggressive = ErrorRecoveryStrategy(
    maxAttempts: 5,
    initialDelay: Duration(milliseconds: 500),
    maxDelay: Duration(seconds: 60),
    backoffMultiplier: 1.5,
  );
  
  /// Conservative strategy for non-critical operations
  static const ErrorRecoveryStrategy conservative = ErrorRecoveryStrategy(
    maxAttempts: 2,
    initialDelay: Duration(seconds: 2),
    maxDelay: Duration(seconds: 10),
    backoffMultiplier: 2.0,
  );
  
  /// Strategy for file uploads
  static const ErrorRecoveryStrategy fileUpload = ErrorRecoveryStrategy(
    maxAttempts: 3,
    initialDelay: Duration(seconds: 1),
    maxDelay: Duration(seconds: 30),
    backoffMultiplier: 2.0,
    retryableExceptions: [
      NetworkException,
      TimeoutException,
      ServerException,
      FileUploadException,
    ],
  );
  
  /// Strategy for authentication operations
  static const ErrorRecoveryStrategy authentication = ErrorRecoveryStrategy(
    maxAttempts: 2,
    initialDelay: Duration(seconds: 1),
    maxDelay: Duration(seconds: 5),
    backoffMultiplier: 2.0,
    retryableExceptions: [
      NetworkException,
      TimeoutException,
      ServerException,
    ],
  );
}

/// Error recovery manager for handling retries and error recovery
class ErrorRecoveryManager {
  /// Execute operation with error recovery
  static Future<T> executeWithRecovery<T>(
    Future<T> Function() operation, {
    ErrorRecoveryStrategy strategy = ErrorRecoveryStrategies.defaultStrategy,
    String? operationName,
    void Function(Exception error, int attempt)? onRetry,
    void Function(Exception error)? onFinalFailure,
  }) async {
    int attempts = 0;
    Exception? lastError;
    
    while (attempts < strategy.maxAttempts) {
      attempts++;
      
      try {
        developer.log(
          'Executing ${operationName ?? 'operation'} (attempt $attempts/${strategy.maxAttempts})',
          name: 'ErrorRecoveryManager',
        );
        
        final result = await operation();
        
        if (attempts > 1) {
          developer.log(
            '${operationName ?? 'Operation'} succeeded after $attempts attempts',
            name: 'ErrorRecoveryManager',
          );
        }
        
        return result;
      } catch (e) {
        lastError = e as Exception;
        
        developer.log(
          '${operationName ?? 'Operation'} failed (attempt $attempts): $e',
          name: 'ErrorRecoveryManager',
        );
        
        // Check if we should retry
        if (attempts < strategy.maxAttempts && strategy.isRetryable(lastError)) {
          final delay = strategy.calculateDelay(attempts);
          
          developer.log(
            'Retrying ${operationName ?? 'operation'} in ${delay.inMilliseconds}ms',
            name: 'ErrorRecoveryManager',
          );
          
          // Notify about retry
          onRetry?.call(lastError, attempts);
          
          // Wait before retry
          await Future.delayed(delay);
        } else {
          // No more retries or not retryable
          break;
        }
      }
    }
    
    // All attempts failed
    developer.log(
      '${operationName ?? 'Operation'} failed after $attempts attempts: $lastError',
      name: 'ErrorRecoveryManager',
    );
    
    onFinalFailure?.call(lastError!);
    throw lastError!;
  }
  
  /// Execute operation with custom retry condition
  static Future<T> executeWithCustomRetry<T>(
    Future<T> Function() operation, {
    required bool Function(Exception error, int attempt) shouldRetry,
    required Duration Function(Exception error, int attempt) getDelay,
    int maxAttempts = 3,
    String? operationName,
    void Function(Exception error, int attempt)? onRetry,
    void Function(Exception error)? onFinalFailure,
  }) async {
    int attempts = 0;
    Exception? lastError;
    
    while (attempts < maxAttempts) {
      attempts++;
      
      try {
        developer.log(
          'Executing ${operationName ?? 'operation'} (attempt $attempts/$maxAttempts)',
          name: 'ErrorRecoveryManager',
        );
        
        return await operation();
      } catch (e) {
        lastError = e as Exception;
        
        developer.log(
          '${operationName ?? 'Operation'} failed (attempt $attempts): $e',
          name: 'ErrorRecoveryManager',
        );
        
        // Check if we should retry
        if (attempts < maxAttempts && shouldRetry(lastError, attempts)) {
          final delay = getDelay(lastError, attempts);
          
          developer.log(
            'Retrying ${operationName ?? 'operation'} in ${delay.inMilliseconds}ms',
            name: 'ErrorRecoveryManager',
          );
          
          // Notify about retry
          onRetry?.call(lastError, attempts);
          
          // Wait before retry
          await Future.delayed(delay);
        } else {
          // No more retries or should not retry
          break;
        }
      }
    }
    
    // All attempts failed
    developer.log(
      '${operationName ?? 'Operation'} failed after $attempts attempts: $lastError',
      name: 'ErrorRecoveryManager',
    );
    
    onFinalFailure?.call(lastError!);
    throw lastError!;
  }
  
  /// Execute multiple operations with recovery
  static Future<List<T>> executeMultipleWithRecovery<T>(
    List<Future<T> Function()> operations, {
    ErrorRecoveryStrategy strategy = ErrorRecoveryStrategies.defaultStrategy,
    bool failFast = false,
    String? operationName,
    void Function(int index, Exception error, int attempt)? onRetry,
    void Function(int index, Exception error)? onFailure,
  }) async {
    final results = <T>[];
    final errors = <Exception>[];
    
    for (int i = 0; i < operations.length; i++) {
      try {
        final result = await executeWithRecovery(
          operations[i],
          strategy: strategy,
          operationName: '${operationName ?? 'operation'} $i',
          onRetry: (error, attempt) => onRetry?.call(i, error, attempt),
          onFinalFailure: (error) => onFailure?.call(i, error),
        );
        results.add(result);
      } catch (e) {
        errors.add(e as Exception);
        
        if (failFast) {
          throw e;
        }
      }
    }
    
    if (errors.isNotEmpty && results.isEmpty) {
      // All operations failed
      throw errors.first;
    }
    
    return results;
  }
  
  /// Create a circuit breaker for repeated failures
  static CircuitBreaker createCircuitBreaker({
    int failureThreshold = 5,
    Duration timeout = const Duration(minutes: 1),
    Duration resetTimeout = const Duration(minutes: 5),
  }) {
    return CircuitBreaker(
      failureThreshold: failureThreshold,
      timeout: timeout,
      resetTimeout: resetTimeout,
    );
  }
}

/// Circuit breaker implementation for preventing cascading failures
class CircuitBreaker {
  final int failureThreshold;
  final Duration timeout;
  final Duration resetTimeout;
  
  int _failureCount = 0;
  DateTime? _lastFailureTime;
  bool _isOpen = false;
  
  CircuitBreaker({
    required this.failureThreshold,
    required this.timeout,
    required this.resetTimeout,
  });
  
  /// Execute operation through circuit breaker
  Future<T> execute<T>(
    Future<T> Function() operation, {
    String? operationName,
  }) async {
    // Check if circuit is open
    if (_isOpen) {
      if (_lastFailureTime != null &&
          DateTime.now().difference(_lastFailureTime!) > resetTimeout) {
        // Try to reset circuit
        _reset();
        developer.log(
          'Circuit breaker reset for ${operationName ?? 'operation'}',
          name: 'CircuitBreaker',
        );
      } else {
        throw ApiException(
          'Circuit breaker is open for ${operationName ?? 'operation'}. Try again later.',
        );
      }
    }
    
    try {
      final result = await operation().timeout(timeout);
      _onSuccess();
      return result;
    } catch (e) {
      _onFailure();
      
      if (_failureCount >= failureThreshold) {
        _open();
        developer.log(
          'Circuit breaker opened for ${operationName ?? 'operation'} after $_failureCount failures',
          name: 'CircuitBreaker',
        );
      }
      
      rethrow;
    }
  }
  
  void _onSuccess() {
    _failureCount = 0;
    _lastFailureTime = null;
  }
  
  void _onFailure() {
    _failureCount++;
    _lastFailureTime = DateTime.now();
  }
  
  void _open() {
    _isOpen = true;
  }
  
  void _reset() {
    _isOpen = false;
    _failureCount = 0;
    _lastFailureTime = null;
  }
  
  /// Get current circuit breaker state
  Map<String, dynamic> getState() {
    return {
      'isOpen': _isOpen,
      'failureCount': _failureCount,
      'lastFailureTime': _lastFailureTime?.toIso8601String(),
      'failureThreshold': failureThreshold,
    };
  }
}