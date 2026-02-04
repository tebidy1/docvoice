/// Enhanced API client for ScribeFlow backend integration
/// 
/// This file contains the main API client implementation using Dio,
/// with automatic token management, error handling, and request/response interceptors.

import 'dart:developer' as developer;
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import '../auth/token_manager.dart';
import '../config/api_config.dart';
import '../error/api_error_handler.dart';
import '../error/api_exceptions.dart';
import '../models/api_models.dart';

/// Enhanced API client for Laravel backend communication
class ApiClient {
  late final Dio _dio;
  final TokenManager _tokenManager;
  final String baseUrl;
  
  // Track refresh attempts to prevent infinite loops
  bool _isRefreshing = false;
  final List<RequestOptions> _failedQueue = [];
  
  ApiClient({
    required this.baseUrl,
    TokenManager? tokenManager,
  }) : _tokenManager = tokenManager ?? TokenManager() {
    _initializeDio();
  }
  
  /// Initialize Dio with configuration and interceptors
  void _initializeDio() {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(milliseconds: ApiConfig.requestTimeout),
      receiveTimeout: const Duration(milliseconds: ApiConfig.requestTimeout),
      sendTimeout: const Duration(milliseconds: ApiConfig.requestTimeout),
      headers: ApiConfig.defaultHeaders,
      validateStatus: (status) {
        // Accept all status codes to handle them in interceptors
        return status != null && status < 600;
      },
    ));
    
    _setupInterceptors();
    _setupCertificateHandling();
  }
  
  /// Setup request/response interceptors
  void _setupInterceptors() {
    // Request interceptor for authentication and logging
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        await _handleRequest(options, handler);
      },
      onResponse: (response, handler) async {
        await _handleResponse(response, handler);
      },
      onError: (error, handler) async {
        await _handleError(error, handler);
      },
    ));
    
    // Logging interceptor for debugging
    if (developer.log != null) {
      _dio.interceptors.add(LogInterceptor(
        requestBody: true,
        responseBody: true,
        requestHeader: true,
        responseHeader: false,
        error: true,
        logPrint: (object) {
          developer.log(object.toString(), name: 'ApiClient');
        },
      ));
    }
  }
  
  /// Setup certificate handling for development/testing
  void _setupCertificateHandling() {
    (_dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
      final client = HttpClient();
      
      // In development, you might want to accept self-signed certificates
      // Remove this in production!
      client.badCertificateCallback = (cert, host, port) {
        developer.log(
          'Certificate warning for $host:$port - ${cert.subject}',
          name: 'ApiClient',
        );
        // Only accept for development domains
        return host.contains('localhost') || 
               host.contains('127.0.0.1') ||
               host.contains('.test') ||
               host.contains('.local');
      };
      
      return client;
    };
  }
  
  /// Handle outgoing requests
  Future<void> _handleRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    try {
      // Add authentication header if available
      final authHeader = await _tokenManager.getAuthorizationHeader();
      if (authHeader != null) {
        options.headers['Authorization'] = authHeader;
      }
      
      // Add request ID for tracking
      options.headers['X-Request-ID'] = DateTime.now().millisecondsSinceEpoch.toString();
      
      developer.log(
        'Request: ${options.method} ${options.path}',
        name: 'ApiClient',
      );
      
      handler.next(options);
    } catch (e) {
      developer.log('Request interceptor error: $e', name: 'ApiClient');
      handler.reject(DioException(
        requestOptions: options,
        error: e,
        message: 'Request preparation failed',
      ));
    }
  }
  
  /// Handle incoming responses
  Future<void> _handleResponse(Response response, ResponseInterceptorHandler handler) async {
    try {
      developer.log(
        'Response: ${response.statusCode} ${response.requestOptions.path}',
        name: 'ApiClient',
      );
      
      handler.next(response);
    } catch (e) {
      developer.log('Response interceptor error: $e', name: 'ApiClient');
      handler.next(response);
    }
  }
  
  /// Handle errors and implement token refresh logic
  Future<void> _handleError(DioException error, ErrorInterceptorHandler handler) async {
    try {
      // Handle 401 Unauthorized - attempt token refresh
      if (error.response?.statusCode == 401 && !_isRefreshing) {
        final refreshToken = await _tokenManager.getRefreshToken();
        
        if (refreshToken != null && refreshToken.isNotEmpty) {
          developer.log('Attempting token refresh', name: 'ApiClient');
          
          try {
            await _refreshToken();
            
            // Retry the original request
            final retryResponse = await _retryRequest(error.requestOptions);
            handler.resolve(retryResponse);
            return;
          } catch (refreshError) {
            developer.log('Token refresh failed: $refreshError', name: 'ApiClient');
            
            // Clear tokens and let the error propagate
            await _tokenManager.clearTokens();
          }
        }
      }
      
      // Convert Dio error to API exception
      final apiException = ApiErrorHandler.handleDioError(error);
      ApiErrorHandler.logError(apiException, context: 'ApiClient');
      
      handler.reject(DioException(
        requestOptions: error.requestOptions,
        response: error.response,
        error: apiException,
        message: apiException.message,
      ));
    } catch (e) {
      developer.log('Error interceptor error: $e', name: 'ApiClient');
      handler.next(error);
    }
  }
  
  /// Refresh authentication token
  Future<void> _refreshToken() async {
    if (_isRefreshing) {
      throw AuthenticationException('Token refresh already in progress');
    }
    
    _isRefreshing = true;
    
    try {
      final refreshToken = await _tokenManager.getRefreshToken();
      if (refreshToken == null) {
        throw AuthenticationException('No refresh token available');
      }
      
      // Create a new Dio instance to avoid interceptor loops
      final refreshDio = Dio(BaseOptions(
        baseUrl: baseUrl,
        headers: ApiConfig.defaultHeaders,
      ));
      
      final response = await refreshDio.post(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
      );
      
      if (response.statusCode == 200 && response.data != null) {
        final authResult = AuthResult.fromJson(response.data);
        
        if (authResult.success && authResult.token != null) {
          await _tokenManager.updateAccessToken(
            authResult.token!,
            expiresAt: authResult.expiresAt,
          );
          
          if (authResult.user != null) {
            await _tokenManager.updateUser(authResult.user!);
          }
          
          developer.log('Token refreshed successfully', name: 'ApiClient');
        } else {
          throw AuthenticationException(
            authResult.message ?? 'Token refresh failed'
          );
        }
      } else {
        throw AuthenticationException('Invalid refresh response');
      }
    } finally {
      _isRefreshing = false;
    }
  }
  
  /// Retry a failed request with new token
  Future<Response> _retryRequest(RequestOptions requestOptions) async {
    // Update authorization header with new token
    final authHeader = await _tokenManager.getAuthorizationHeader();
    if (authHeader != null) {
      requestOptions.headers['Authorization'] = authHeader;
    }
    
    developer.log('Retrying request: ${requestOptions.path}', name: 'ApiClient');
    
    return await _dio.fetch(requestOptions);
  }
  
  /// Generic GET request
  Future<ApiResponse<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    T Function(dynamic)? fromJson,
  }) async {
    try {
      final response = await _dio.get(
        path,
        queryParameters: queryParameters,
        options: options,
      );
      
      return _handleSuccessResponse<T>(response, fromJson);
    } on DioException catch (e) {
      return _handleErrorResponse<T>(e);
    }
  }
  
  /// Generic POST request
  Future<ApiResponse<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    T Function(dynamic)? fromJson,
  }) async {
    try {
      final response = await _dio.post(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
      
      return _handleSuccessResponse<T>(response, fromJson);
    } on DioException catch (e) {
      return _handleErrorResponse<T>(e);
    }
  }
  
  /// Generic PUT request
  Future<ApiResponse<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    T Function(dynamic)? fromJson,
  }) async {
    try {
      final response = await _dio.put(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
      
      return _handleSuccessResponse<T>(response, fromJson);
    } on DioException catch (e) {
      return _handleErrorResponse<T>(e);
    }
  }
  
  /// Generic PATCH request
  Future<ApiResponse<T>> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    T Function(dynamic)? fromJson,
  }) async {
    try {
      final response = await _dio.patch(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
      
      return _handleSuccessResponse<T>(response, fromJson);
    } on DioException catch (e) {
      return _handleErrorResponse<T>(e);
    }
  }
  
  /// Generic DELETE request
  Future<ApiResponse<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    T Function(dynamic)? fromJson,
  }) async {
    try {
      final response = await _dio.delete(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
      
      return _handleSuccessResponse<T>(response, fromJson);
    } on DioException catch (e) {
      return _handleErrorResponse<T>(e);
    }
  }
  
  /// Upload file with progress tracking
  Future<ApiResponse<FileUploadResult>> uploadFile(
    String path,
    File file, {
    String? fileName,
    Map<String, dynamic>? additionalData,
    void Function(int sent, int total)? onSendProgress,
  }) async {
    try {
      final formData = FormData();
      
      // Add file
      formData.files.add(MapEntry(
        'file',
        await MultipartFile.fromFile(
          file.path,
          filename: fileName ?? file.path.split('/').last,
        ),
      ));
      
      // Add additional data
      if (additionalData != null) {
        for (final entry in additionalData.entries) {
          formData.fields.add(MapEntry(entry.key, entry.value.toString()));
        }
      }
      
      final response = await _dio.post(
        path,
        data: formData,
        options: Options(
          headers: {'Content-Type': 'multipart/form-data'},
        ),
        onSendProgress: onSendProgress,
      );
      
      return _handleSuccessResponse<FileUploadResult>(
        response,
        (data) => FileUploadResult.fromJson(data as Map<String, dynamic>),
      );
    } on DioException catch (e) {
      return _handleErrorResponse<FileUploadResult>(e);
    }
  }
  
  /// Handle successful responses
  ApiResponse<T> _handleSuccessResponse<T>(
    Response response,
    T Function(dynamic)? fromJson,
  ) {
    if (response.statusCode != null && response.statusCode! >= 400) {
      // This shouldn't happen due to validateStatus, but handle it anyway
      final error = ApiErrorHandler.handleDioError(
        DioException(
          requestOptions: response.requestOptions,
          response: response,
        ),
      );
      return ApiResponse.error(error.message, statusCode: response.statusCode);
    }
    
    try {
      T? data;
      if (fromJson != null && response.data != null) {
        // Handle both direct data and wrapped responses
        final responseData = response.data;
        if (responseData is Map<String, dynamic> && responseData.containsKey('data')) {
          data = fromJson(responseData['data']);
        } else {
          data = fromJson(responseData);
        }
      } else {
        data = response.data as T?;
      }
      
      return ApiResponse.success(
        data,
        message: response.data is Map<String, dynamic> 
            ? response.data['message']?.toString()
            : null,
      );
    } catch (e) {
      developer.log('Response parsing error: $e', name: 'ApiClient');
      return ApiResponse.error('Failed to parse response data');
    }
  }
  
  /// Handle error responses
  ApiResponse<T> _handleErrorResponse<T>(DioException error) {
    final apiException = error.error is ApiException 
        ? error.error as ApiException
        : ApiErrorHandler.handleDioError(error);
    
    return ApiResponse.error(
      apiException.message,
      statusCode: apiException.statusCode,
    );
  }
  
  /// Get current authentication status
  Future<bool> isAuthenticated() async {
    return await _tokenManager.isAuthenticated();
  }
  
  /// Get current user information
  Future<User?> getCurrentUser() async {
    return await _tokenManager.getUser();
  }
  
  /// Clear authentication tokens
  Future<void> clearAuth() async {
    await _tokenManager.clearTokens();
  }
  
  /// Get token information for debugging
  Future<Map<String, dynamic>> getTokenInfo() async {
    return await _tokenManager.getTokenInfo();
  }
  
  /// Close the client and clean up resources
  void close() {
    _dio.close();
  }
}