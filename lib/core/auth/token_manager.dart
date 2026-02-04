/// Token management for ScribeFlow backend integration
/// 
/// This file handles secure storage and management of JWT tokens,
/// including automatic refresh capabilities and token validation.

import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/api_models.dart';
import '../error/api_exceptions.dart';

/// Token storage keys
class _TokenKeys {
  static const String accessToken = 'access_token';
  static const String refreshToken = 'refresh_token';
  static const String tokenExpiry = 'token_expiry';
  static const String userInfo = 'user_info';
}

/// Token manager for handling JWT tokens and user authentication state
class TokenManager {
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainItemAccessibility.first_unlock_this_device,
    ),
    lOptions: LinuxOptions(
      useSessionKeyring: true,
    ),
    wOptions: WindowsOptions(
      useBackwardCompatibility: false,
    ),
  );
  
  /// Store authentication tokens and user information
  Future<void> storeTokens({
    required String accessToken,
    String? refreshToken,
    DateTime? expiresAt,
    User? user,
  }) async {
    try {
      await _storage.write(key: _TokenKeys.accessToken, value: accessToken);
      
      if (refreshToken != null) {
        await _storage.write(key: _TokenKeys.refreshToken, value: refreshToken);
      }
      
      if (expiresAt != null) {
        await _storage.write(
          key: _TokenKeys.tokenExpiry,
          value: expiresAt.toIso8601String(),
        );
      }
      
      if (user != null) {
        await _storage.write(
          key: _TokenKeys.userInfo,
          value: jsonEncode(user.toJson()),
        );
      }
      
      developer.log('Tokens stored successfully', name: 'TokenManager');
    } catch (e) {
      developer.log('Failed to store tokens: $e', name: 'TokenManager');
      throw AuthenticationException('Failed to store authentication tokens');
    }
  }
  
  /// Get the current access token
  Future<String?> getAccessToken() async {
    try {
      return await _storage.read(key: _TokenKeys.accessToken);
    } catch (e) {
      developer.log('Failed to read access token: $e', name: 'TokenManager');
      return null;
    }
  }
  
  /// Get the current refresh token
  Future<String?> getRefreshToken() async {
    try {
      return await _storage.read(key: _TokenKeys.refreshToken);
    } catch (e) {
      developer.log('Failed to read refresh token: $e', name: 'TokenManager');
      return null;
    }
  }
  
  /// Get token expiry date
  Future<DateTime?> getTokenExpiry() async {
    try {
      final expiryString = await _storage.read(key: _TokenKeys.tokenExpiry);
      if (expiryString != null) {
        return DateTime.parse(expiryString);
      }
      return null;
    } catch (e) {
      developer.log('Failed to read token expiry: $e', name: 'TokenManager');
      return null;
    }
  }
  
  /// Get stored user information
  Future<User?> getUser() async {
    try {
      final userString = await _storage.read(key: _TokenKeys.userInfo);
      if (userString != null) {
        final userJson = jsonDecode(userString) as Map<String, dynamic>;
        return User.fromJson(userJson);
      }
      return null;
    } catch (e) {
      developer.log('Failed to read user info: $e', name: 'TokenManager');
      return null;
    }
  }
  
  /// Check if the current token is expired
  Future<bool> isTokenExpired() async {
    try {
      final expiry = await getTokenExpiry();
      if (expiry == null) {
        // If no expiry is set, assume token is valid for now
        // This will be handled by the API client when it receives 401
        return false;
      }
      
      // Add a 5-minute buffer to refresh before actual expiry
      final bufferTime = DateTime.now().add(const Duration(minutes: 5));
      return expiry.isBefore(bufferTime);
    } catch (e) {
      developer.log('Failed to check token expiry: $e', name: 'TokenManager');
      return true; // Assume expired on error
    }
  }
  
  /// Check if user is authenticated (has valid tokens)
  Future<bool> isAuthenticated() async {
    try {
      final accessToken = await getAccessToken();
      if (accessToken == null || accessToken.isEmpty) {
        return false;
      }
      
      // Check if token is expired
      final isExpired = await isTokenExpired();
      if (isExpired) {
        // Check if we have a refresh token
        final refreshToken = await getRefreshToken();
        return refreshToken != null && refreshToken.isNotEmpty;
      }
      
      return true;
    } catch (e) {
      developer.log('Failed to check authentication status: $e', name: 'TokenManager');
      return false;
    }
  }
  
  /// Update access token (typically after refresh)
  Future<void> updateAccessToken(String accessToken, {DateTime? expiresAt}) async {
    try {
      await _storage.write(key: _TokenKeys.accessToken, value: accessToken);
      
      if (expiresAt != null) {
        await _storage.write(
          key: _TokenKeys.tokenExpiry,
          value: expiresAt.toIso8601String(),
        );
      }
      
      developer.log('Access token updated successfully', name: 'TokenManager');
    } catch (e) {
      developer.log('Failed to update access token: $e', name: 'TokenManager');
      throw AuthenticationException('Failed to update access token');
    }
  }
  
  /// Update user information
  Future<void> updateUser(User user) async {
    try {
      await _storage.write(
        key: _TokenKeys.userInfo,
        value: jsonEncode(user.toJson()),
      );
      
      developer.log('User info updated successfully', name: 'TokenManager');
    } catch (e) {
      developer.log('Failed to update user info: $e', name: 'TokenManager');
      throw AuthenticationException('Failed to update user information');
    }
  }
  
  /// Clear all stored tokens and user information
  Future<void> clearTokens() async {
    try {
      await Future.wait([
        _storage.delete(key: _TokenKeys.accessToken),
        _storage.delete(key: _TokenKeys.refreshToken),
        _storage.delete(key: _TokenKeys.tokenExpiry),
        _storage.delete(key: _TokenKeys.userInfo),
      ]);
      
      developer.log('All tokens cleared successfully', name: 'TokenManager');
    } catch (e) {
      developer.log('Failed to clear tokens: $e', name: 'TokenManager');
      // Don't throw here as this is typically called during logout
      // and we want to ensure the user is logged out even if clearing fails
    }
  }
  
  /// Get authorization header value
  Future<String?> getAuthorizationHeader() async {
    final token = await getAccessToken();
    if (token != null && token.isNotEmpty) {
      return 'Bearer $token';
    }
    return null;
  }
  
  /// Validate token format (basic JWT structure check)
  bool isValidTokenFormat(String token) {
    if (token.isEmpty) return false;
    
    // Basic JWT format check: should have 3 parts separated by dots
    final parts = token.split('.');
    if (parts.length != 3) return false;
    
    // Each part should be base64 encoded (basic check)
    for (final part in parts) {
      if (part.isEmpty) return false;
    }
    
    return true;
  }
  
  /// Extract token expiry from JWT payload (without verification)
  /// This is a fallback method when server doesn't provide expiry
  DateTime? extractTokenExpiry(String token) {
    try {
      if (!isValidTokenFormat(token)) return null;
      
      final parts = token.split('.');
      final payload = parts[1];
      
      // Add padding if needed for base64 decoding
      String normalizedPayload = payload;
      while (normalizedPayload.length % 4 != 0) {
        normalizedPayload += '=';
      }
      
      final decodedBytes = base64Url.decode(normalizedPayload);
      final decodedPayload = utf8.decode(decodedBytes);
      final payloadJson = jsonDecode(decodedPayload) as Map<String, dynamic>;
      
      final exp = payloadJson['exp'];
      if (exp != null) {
        // JWT exp is in seconds since epoch
        return DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      }
      
      return null;
    } catch (e) {
      developer.log('Failed to extract token expiry: $e', name: 'TokenManager');
      return null;
    }
  }
  
  /// Get token info for debugging (without sensitive data)
  Future<Map<String, dynamic>> getTokenInfo() async {
    try {
      final hasAccessToken = await getAccessToken() != null;
      final hasRefreshToken = await getRefreshToken() != null;
      final expiry = await getTokenExpiry();
      final isExpired = await isTokenExpired();
      final isAuth = await isAuthenticated();
      final user = await getUser();
      
      return {
        'hasAccessToken': hasAccessToken,
        'hasRefreshToken': hasRefreshToken,
        'tokenExpiry': expiry?.toIso8601String(),
        'isTokenExpired': isExpired,
        'isAuthenticated': isAuth,
        'userId': user?.id,
        'userEmail': user?.email,
      };
    } catch (e) {
      developer.log('Failed to get token info: $e', name: 'TokenManager');
      return {'error': e.toString()};
    }
  }
}