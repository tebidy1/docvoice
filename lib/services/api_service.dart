import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  String? _baseUrl;
  String? _token;
  final int _timeout = int.tryParse(dotenv.env['API_TIMEOUT'] ?? '30000') ?? 30000;

  Future<void> init() async {
    _baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://localhost:8000/api';
    await _loadToken();
  }

  Future<void> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
  }

  Future<void> setToken(String? token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    if (token != null) {
      await prefs.setString('auth_token', token);
    } else {
      await prefs.remove('auth_token');
    }
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  Future<Map<String, dynamic>> get(String endpoint, {Map<String, String>? queryParams}) async {
    try {
      await init();
      var uri = Uri.parse('$_baseUrl$endpoint');
      if (queryParams != null && queryParams.isNotEmpty) {
        uri = uri.replace(queryParameters: queryParams);
      }

      final response = await http
          .get(uri, headers: _headers)
          .timeout(Duration(milliseconds: _timeout));

      return _handleResponse(response);
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> post(String endpoint, {Map<String, dynamic>? body}) async {
    try {
      await init();
      final uri = Uri.parse('$_baseUrl$endpoint');

      final response = await http
          .post(
            uri,
            headers: _headers,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(Duration(milliseconds: _timeout));

      return _handleResponse(response);
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> put(String endpoint, {Map<String, dynamic>? body}) async {
    try {
      await init();
      final uri = Uri.parse('$_baseUrl$endpoint');

      final response = await http
          .put(
            uri,
            headers: _headers,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(Duration(milliseconds: _timeout));

      return _handleResponse(response);
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> patch(String endpoint, {Map<String, dynamic>? body}) async {
    try {
      await init();
      final uri = Uri.parse('$_baseUrl$endpoint');

      final response = await http
          .patch(
            uri,
            headers: _headers,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(Duration(milliseconds: _timeout));

      return _handleResponse(response);
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> delete(String endpoint) async {
    try {
      await init();
      final uri = Uri.parse('$_baseUrl$endpoint');

      final response = await http
          .delete(uri, headers: _headers)
          .timeout(Duration(milliseconds: _timeout));

      return _handleResponse(response);
    } catch (e) {
      throw _handleError(e);
    }
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
    final statusCode = response.statusCode;
    final responseBody = response.body;

    if (responseBody.isEmpty) {
      if (statusCode >= 200 && statusCode < 300) {
        return {'status': true, 'code': statusCode, 'message': 'Success', 'payload': null};
      }
      throw ApiException('Empty response', statusCode);
    }

    try {
      final data = jsonDecode(responseBody) as Map<String, dynamic>;

      // Handle validation errors (422)
      if (statusCode == 422 && data.containsKey('errors')) {
        final errors = data['errors'] as Map<String, dynamic>;
        final firstError = errors.values.first;
        final errorMessage = firstError is List ? firstError.first : firstError.toString();
        throw ApiException(
          errorMessage,
          statusCode,
          errors: errors,
        );
      }

      // Handle Laravel API response format (success/user/token)
      if (data.containsKey('success')) {
        if (data['success'] == true) {
          return data;
        } else {
          throw ApiException(
            data['message'] ?? 'Request failed',
            statusCode,
            errors: data['errors'],
          );
        }
      }

      // Handle standard API response format (status/code/message/payload)
      if (data.containsKey('status')) {
        if (data['status'] == true) {
          return data;
        } else {
          throw ApiException(
            data['message'] ?? 'Request failed',
            statusCode,
            errors: data['errors'],
          );
        }
      }

      // Fallback for non-standard responses
      if (statusCode >= 200 && statusCode < 300) {
        return {'status': true, 'code': statusCode, 'message': 'Success', 'payload': data};
      }

      throw ApiException(
        data['message'] ?? 'Request failed',
        statusCode,
        errors: data['errors'],
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Failed to parse response: $e', statusCode);
    }
  }

  dynamic _handleError(dynamic error) {
    if (error is ApiException) {
      return error;
    }

    if (error.toString().contains('TimeoutException') || error.toString().contains('timeout')) {
      return ApiException('Request timeout. Please check your connection.', 408);
    }

    if (error.toString().contains('SocketException') || error.toString().contains('Failed host lookup')) {
      return ApiException('No internet connection. Please check your network.', 0);
    }

    return ApiException('An unexpected error occurred: $error', 500);
  }
}

class ApiException implements Exception {
  final String message;
  final int statusCode;
  final Map<String, dynamic>? errors;

  ApiException(this.message, this.statusCode, {this.errors});

  @override
  String toString() => message;

  bool get isUnauthorized => statusCode == 401;
  bool get isValidationError => statusCode == 422;
  bool get isServerError => statusCode >= 500;
  bool get isNotFound => statusCode == 404;
}
