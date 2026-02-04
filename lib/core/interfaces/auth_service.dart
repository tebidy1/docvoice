/// Authentication service interface for ScribeFlow backend integration
/// 
/// This file defines the contract for authentication services,
/// including login, registration, logout, and profile management.

import '../models/api_models.dart';

/// Authentication state enumeration
enum AuthState {
  /// User is not authenticated
  unauthenticated,
  
  /// Authentication is in progress
  authenticating,
  
  /// User is authenticated
  authenticated,
  
  /// Authentication error occurred
  error,
  
  /// Token is being refreshed
  refreshing,
}

/// Authentication service interface
abstract class AuthService {
  /// Get current authentication state
  AuthState get currentState;
  
  /// Stream of authentication state changes
  Stream<AuthState> get authStateStream;
  
  /// Get current authenticated user
  User? get currentUser;
  
  /// Stream of user changes
  Stream<User?> get userStream;
  
  /// Authenticate user with email and password
  /// 
  /// Returns [AuthResult] with success status, user info, and tokens
  Future<AuthResult> login(String email, String password, {String? deviceName});
  
  /// Register new user account
  /// 
  /// Returns [AuthResult] with success status, user info, and tokens
  Future<AuthResult> register({
    required String name,
    required String email,
    required String password,
    String? passwordConfirmation,
    Map<String, dynamic>? additionalData,
  });
  
  /// Logout current user
  /// 
  /// Clears local tokens and notifies backend
  Future<void> logout();
  
  /// Get current user profile
  /// 
  /// Returns updated user information from backend
  Future<User> getProfile();
  
  /// Update user profile
  /// 
  /// Returns updated user information
  Future<User> updateProfile(User user);
  
  /// Change user password
  /// 
  /// Requires current password for verification
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    String? newPasswordConfirmation,
  });
  
  /// Request password reset
  /// 
  /// Sends password reset email to user
  Future<void> requestPasswordReset(String email);
  
  /// Reset password with token
  /// 
  /// Uses token from password reset email
  Future<void> resetPassword({
    required String token,
    required String email,
    required String password,
    String? passwordConfirmation,
  });
  
  /// Verify email address
  /// 
  /// Uses verification token from email
  Future<void> verifyEmail({
    required String token,
    required String email,
  });
  
  /// Resend email verification
  /// 
  /// Sends new verification email to current user
  Future<void> resendEmailVerification();
  
  /// Check if user is currently authenticated
  /// 
  /// Validates token and returns authentication status
  Future<bool> isAuthenticated();
  
  /// Refresh authentication token
  /// 
  /// Uses refresh token to get new access token
  Future<void> refreshToken();
  
  /// Get current access token
  /// 
  /// Returns null if not authenticated
  Future<String?> getAccessToken();
  
  /// Get authorization header value
  /// 
  /// Returns "Bearer {token}" format or null if not authenticated
  Future<String?> getAuthorizationHeader();
  
  /// Initialize authentication service
  /// 
  /// Checks stored tokens and restores authentication state
  Future<void> initialize();
  
  /// Dispose authentication service
  /// 
  /// Cleans up resources and streams
  Future<void> dispose();
}