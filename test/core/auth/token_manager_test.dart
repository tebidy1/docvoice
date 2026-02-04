/// Unit tests for token manager
/// 
/// Tests secure token storage, retrieval, validation, and management functionality.

import 'package:flutter_test/flutter_test.dart';
import 'package:scribeflow/core/core.dart';

void main() {
  group('TokenManager', () {
    late TokenManager tokenManager;
    
    setUp(() {
      tokenManager = TokenManager();
    });
    
    tearDown(() async {
      // Clean up tokens after each test
      await tokenManager.clearTokens();
    });
    
    group('Token Storage and Retrieval', () {
      test('should store and retrieve access token', () async {
        const token = 'test-access-token';
        
        await tokenManager.storeTokens(accessToken: token);
        final retrievedToken = await tokenManager.getAccessToken();
        
        expect(retrievedToken, equals(token));
      });
      
      test('should store and retrieve refresh token', () async {
        const accessToken = 'test-access-token';
        const refreshToken = 'test-refresh-token';
        
        await tokenManager.storeTokens(
          accessToken: accessToken,
          refreshToken: refreshToken,
        );
        
        final retrievedRefreshToken = await tokenManager.getRefreshToken();
        expect(retrievedRefreshToken, equals(refreshToken));
      });
      
      test('should store and retrieve token expiry', () async {
        const accessToken = 'test-access-token';
        final expiresAt = DateTime.now().add(const Duration(hours: 1));
        
        await tokenManager.storeTokens(
          accessToken: accessToken,
          expiresAt: expiresAt,
        );
        
        final retrievedExpiry = await tokenManager.getTokenExpiry();
        expect(retrievedExpiry, isNotNull);
        // Allow small difference due to serialization
        expect(
          retrievedExpiry!.difference(expiresAt).abs(),
          lessThan(const Duration(seconds: 1)),
        );
      });
      
      test('should store and retrieve user information', () async {
        const accessToken = 'test-access-token';
        final user = User(
          id: '1',
          name: 'Test User',
          email: 'test@example.com',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        
        await tokenManager.storeTokens(
          accessToken: accessToken,
          user: user,
        );
        
        final retrievedUser = await tokenManager.getUser();
        expect(retrievedUser, isNotNull);
        expect(retrievedUser!.id, equals(user.id));
        expect(retrievedUser.name, equals(user.name));
        expect(retrievedUser.email, equals(user.email));
      });
    });
    
    group('Token Validation', () {
      test('should validate JWT token format', () {
        // Valid JWT format (3 parts separated by dots)
        const validToken = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c';
        const invalidToken1 = 'invalid-token';
        const invalidToken2 = 'part1.part2'; // Only 2 parts
        const invalidToken3 = ''; // Empty
        
        expect(tokenManager.isValidTokenFormat(validToken), isTrue);
        expect(tokenManager.isValidTokenFormat(invalidToken1), isFalse);
        expect(tokenManager.isValidTokenFormat(invalidToken2), isFalse);
        expect(tokenManager.isValidTokenFormat(invalidToken3), isFalse);
      });
      
      test('should extract token expiry from JWT payload', () {
        // JWT with exp claim (expires in year 2030)
        const tokenWithExp = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiZXhwIjoxODkzNDU2MDAwfQ.invalid-signature';
        
        final expiry = tokenManager.extractTokenExpiry(tokenWithExp);
        expect(expiry, isNotNull);
        expect(expiry!.year, equals(2030));
      });
      
      test('should return null for token without exp claim', () {
        // JWT without exp claim
        const tokenWithoutExp = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIn0.invalid-signature';
        
        final expiry = tokenManager.extractTokenExpiry(tokenWithoutExp);
        expect(expiry, isNull);
      });
    });
    
    group('Authentication Status', () {
      test('should return false when no tokens stored', () async {
        final isAuth = await tokenManager.isAuthenticated();
        expect(isAuth, isFalse);
      });
      
      test('should return true when valid token stored', () async {
        const accessToken = 'test-access-token';
        final expiresAt = DateTime.now().add(const Duration(hours: 1));
        
        await tokenManager.storeTokens(
          accessToken: accessToken,
          expiresAt: expiresAt,
        );
        
        final isAuth = await tokenManager.isAuthenticated();
        expect(isAuth, isTrue);
      });
      
      test('should return true when token expired but refresh token available', () async {
        const accessToken = 'test-access-token';
        const refreshToken = 'test-refresh-token';
        final expiresAt = DateTime.now().subtract(const Duration(hours: 1)); // Expired
        
        await tokenManager.storeTokens(
          accessToken: accessToken,
          refreshToken: refreshToken,
          expiresAt: expiresAt,
        );
        
        final isAuth = await tokenManager.isAuthenticated();
        expect(isAuth, isTrue); // Should be true because refresh token is available
      });
      
      test('should return false when token expired and no refresh token', () async {
        const accessToken = 'test-access-token';
        final expiresAt = DateTime.now().subtract(const Duration(hours: 1)); // Expired
        
        await tokenManager.storeTokens(
          accessToken: accessToken,
          expiresAt: expiresAt,
        );
        
        final isAuth = await tokenManager.isAuthenticated();
        expect(isAuth, isFalse);
      });
    });
    
    group('Token Expiry Checking', () {
      test('should return false for non-expired token', () async {
        const accessToken = 'test-access-token';
        final expiresAt = DateTime.now().add(const Duration(hours: 1));
        
        await tokenManager.storeTokens(
          accessToken: accessToken,
          expiresAt: expiresAt,
        );
        
        final isExpired = await tokenManager.isTokenExpired();
        expect(isExpired, isFalse);
      });
      
      test('should return true for expired token', () async {
        const accessToken = 'test-access-token';
        final expiresAt = DateTime.now().subtract(const Duration(hours: 1));
        
        await tokenManager.storeTokens(
          accessToken: accessToken,
          expiresAt: expiresAt,
        );
        
        final isExpired = await tokenManager.isTokenExpired();
        expect(isExpired, isTrue);
      });
      
      test('should return true for token expiring within buffer time', () async {
        const accessToken = 'test-access-token';
        final expiresAt = DateTime.now().add(const Duration(minutes: 2)); // Within 5-minute buffer
        
        await tokenManager.storeTokens(
          accessToken: accessToken,
          expiresAt: expiresAt,
        );
        
        final isExpired = await tokenManager.isTokenExpired();
        expect(isExpired, isTrue); // Should be true due to buffer
      });
      
      test('should return false when no expiry set', () async {
        const accessToken = 'test-access-token';
        
        await tokenManager.storeTokens(accessToken: accessToken);
        
        final isExpired = await tokenManager.isTokenExpired();
        expect(isExpired, isFalse); // Should assume valid when no expiry
      });
    });
    
    group('Token Updates', () {
      test('should update access token', () async {
        const initialToken = 'initial-token';
        const updatedToken = 'updated-token';
        
        await tokenManager.storeTokens(accessToken: initialToken);
        await tokenManager.updateAccessToken(updatedToken);
        
        final retrievedToken = await tokenManager.getAccessToken();
        expect(retrievedToken, equals(updatedToken));
      });
      
      test('should update user information', () async {
        const accessToken = 'test-access-token';
        final initialUser = User(
          id: '1',
          name: 'Initial User',
          email: 'initial@example.com',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        
        final updatedUser = initialUser.copyWith(name: 'Updated User');
        
        await tokenManager.storeTokens(accessToken: accessToken, user: initialUser);
        await tokenManager.updateUser(updatedUser);
        
        final retrievedUser = await tokenManager.getUser();
        expect(retrievedUser?.name, equals('Updated User'));
        expect(retrievedUser?.email, equals('initial@example.com')); // Should remain same
      });
    });
    
    group('Authorization Header', () {
      test('should return Bearer token format', () async {
        const accessToken = 'test-access-token';
        
        await tokenManager.storeTokens(accessToken: accessToken);
        
        final authHeader = await tokenManager.getAuthorizationHeader();
        expect(authHeader, equals('Bearer $accessToken'));
      });
      
      test('should return null when no token stored', () async {
        final authHeader = await tokenManager.getAuthorizationHeader();
        expect(authHeader, isNull);
      });
    });
    
    group('Token Clearing', () {
      test('should clear all tokens and user data', () async {
        const accessToken = 'test-access-token';
        const refreshToken = 'test-refresh-token';
        final user = User(
          id: '1',
          name: 'Test User',
          email: 'test@example.com',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        
        await tokenManager.storeTokens(
          accessToken: accessToken,
          refreshToken: refreshToken,
          user: user,
        );
        
        // Verify tokens are stored
        expect(await tokenManager.getAccessToken(), isNotNull);
        expect(await tokenManager.getRefreshToken(), isNotNull);
        expect(await tokenManager.getUser(), isNotNull);
        
        // Clear tokens
        await tokenManager.clearTokens();
        
        // Verify tokens are cleared
        expect(await tokenManager.getAccessToken(), isNull);
        expect(await tokenManager.getRefreshToken(), isNull);
        expect(await tokenManager.getUser(), isNull);
        expect(await tokenManager.isAuthenticated(), isFalse);
      });
    });
    
    group('Token Info', () {
      test('should return comprehensive token information', () async {
        const accessToken = 'test-access-token';
        const refreshToken = 'test-refresh-token';
        final expiresAt = DateTime.now().add(const Duration(hours: 1));
        final user = User(
          id: '1',
          name: 'Test User',
          email: 'test@example.com',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        
        await tokenManager.storeTokens(
          accessToken: accessToken,
          refreshToken: refreshToken,
          expiresAt: expiresAt,
          user: user,
        );
        
        final tokenInfo = await tokenManager.getTokenInfo();
        
        expect(tokenInfo['hasAccessToken'], isTrue);
        expect(tokenInfo['hasRefreshToken'], isTrue);
        expect(tokenInfo['tokenExpiry'], isNotNull);
        expect(tokenInfo['isTokenExpired'], isFalse);
        expect(tokenInfo['isAuthenticated'], isTrue);
        expect(tokenInfo['userId'], equals('1'));
        expect(tokenInfo['userEmail'], equals('test@example.com'));
      });
      
      test('should return empty info when no tokens stored', () async {
        final tokenInfo = await tokenManager.getTokenInfo();
        
        expect(tokenInfo['hasAccessToken'], isFalse);
        expect(tokenInfo['hasRefreshToken'], isFalse);
        expect(tokenInfo['tokenExpiry'], isNull);
        expect(tokenInfo['isAuthenticated'], isFalse);
        expect(tokenInfo['userId'], isNull);
        expect(tokenInfo['userEmail'], isNull);
      });
    });
  });
}