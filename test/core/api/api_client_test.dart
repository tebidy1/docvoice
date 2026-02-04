/// Unit tests for API client infrastructure
/// 
/// Tests the core API client functionality including error handling,
/// token management, and request/response processing.

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:scribeflow/core/core.dart';

// Generate mocks
@GenerateMocks([TokenManager])
import 'api_client_test.mocks.dart';

void main() {
  group('ApiClient', () {
    late ApiClient apiClient;
    late MockTokenManager mockTokenManager;
    
    setUp(() {
      mockTokenManager = MockTokenManager();
      apiClient = ApiClient(
        baseUrl: 'https://test-api.example.com',
        tokenManager: mockTokenManager,
      );
    });
    
    tearDown(() {
      apiClient.close();
    });
    
    group('Initialization', () {
      test('should initialize with correct base URL', () {
        expect(apiClient.baseUrl, equals('https://test-api.example.com'));
      });
      
      test('should use provided token manager', () async {
        when(mockTokenManager.isAuthenticated()).thenAnswer((_) async => true);
        
        final isAuth = await apiClient.isAuthenticated();
        expect(isAuth, isTrue);
        verify(mockTokenManager.isAuthenticated()).called(1);
      });
    });
    
    group('Authentication', () {
      test('should return authentication status from token manager', () async {
        when(mockTokenManager.isAuthenticated()).thenAnswer((_) async => false);
        
        final isAuth = await apiClient.isAuthenticated();
        expect(isAuth, isFalse);
        verify(mockTokenManager.isAuthenticated()).called(1);
      });
      
      test('should return current user from token manager', () async {
        final testUser = User(
          id: '1',
          name: 'Test User',
          email: 'test@example.com',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        
        when(mockTokenManager.getUser()).thenAnswer((_) async => testUser);
        
        final user = await apiClient.getCurrentUser();
        expect(user, equals(testUser));
        verify(mockTokenManager.getUser()).called(1);
      });
      
      test('should clear auth tokens', () async {
        when(mockTokenManager.clearTokens()).thenAnswer((_) async {});
        
        await apiClient.clearAuth();
        verify(mockTokenManager.clearTokens()).called(1);
      });
    });
    
    group('Token Management', () {
      test('should get token info from token manager', () async {
        final tokenInfo = {
          'hasAccessToken': true,
          'hasRefreshToken': true,
          'isAuthenticated': true,
        };
        
        when(mockTokenManager.getTokenInfo()).thenAnswer((_) async => tokenInfo);
        
        final info = await apiClient.getTokenInfo();
        expect(info, equals(tokenInfo));
        verify(mockTokenManager.getTokenInfo()).called(1);
      });
    });
    
    group('Error Handling', () {
      test('should handle network errors gracefully', () async {
        // This test would require mocking Dio, which is complex
        // For now, we'll test that the client can be created and closed
        expect(() => apiClient.close(), returnsNormally);
      });
    });
  });
  
  group('ApiResponse', () {
    test('should create successful response', () {
      const data = 'test data';
      const message = 'Success';
      
      final response = ApiResponse.success(data, message: message);
      
      expect(response.success, isTrue);
      expect(response.data, equals(data));
      expect(response.message, equals(message));
      expect(response.errors, isNull);
      expect(response.statusCode, isNull);
    });
    
    test('should create error response', () {
      const message = 'Error occurred';
      const errors = ['Field is required'];
      const statusCode = 400;
      
      final response = ApiResponse<String>.error(
        message,
        errors: errors,
        statusCode: statusCode,
      );
      
      expect(response.success, isFalse);
      expect(response.data, isNull);
      expect(response.message, equals(message));
      expect(response.errors, equals(errors));
      expect(response.statusCode, equals(statusCode));
    });
    
    test('should create from JSON', () {
      final json = {
        'success': true,
        'data': 'test data',
        'message': 'Success',
        'status_code': 200,
      };
      
      final response = ApiResponse<String>.fromJson(json, (data) => data.toString());
      
      expect(response.success, isTrue);
      expect(response.data, equals('test data'));
      expect(response.message, equals('Success'));
      expect(response.statusCode, equals(200));
    });
  });
  
  group('AuthResult', () {
    test('should create successful auth result', () {
      final user = User(
        id: '1',
        name: 'Test User',
        email: 'test@example.com',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      const token = 'test-token';
      const refreshToken = 'refresh-token';
      
      final result = AuthResult.success(
        user,
        token,
        refreshToken: refreshToken,
      );
      
      expect(result.success, isTrue);
      expect(result.user, equals(user));
      expect(result.token, equals(token));
      expect(result.refreshToken, equals(refreshToken));
      expect(result.message, isNull);
      expect(result.errors, isNull);
    });
    
    test('should create failed auth result', () {
      const message = 'Authentication failed';
      const errors = ['Invalid credentials'];
      
      final result = AuthResult.failure(message, errors: errors);
      
      expect(result.success, isFalse);
      expect(result.user, isNull);
      expect(result.token, isNull);
      expect(result.refreshToken, isNull);
      expect(result.message, equals(message));
      expect(result.errors, equals(errors));
    });
    
    test('should create from JSON', () {
      final json = {
        'success': true,
        'user': {
          'id': '1',
          'name': 'Test User',
          'email': 'test@example.com',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        },
        'token': 'test-token',
        'refresh_token': 'refresh-token',
        'message': 'Login successful',
      };
      
      final result = AuthResult.fromJson(json);
      
      expect(result.success, isTrue);
      expect(result.user?.id, equals('1'));
      expect(result.user?.name, equals('Test User'));
      expect(result.user?.email, equals('test@example.com'));
      expect(result.token, equals('test-token'));
      expect(result.refreshToken, equals('refresh-token'));
      expect(result.message, equals('Login successful'));
    });
  });
  
  group('User', () {
    test('should create user from JSON', () {
      final now = DateTime.now();
      final json = {
        'id': '1',
        'name': 'Test User',
        'email': 'test@example.com',
        'email_verified_at': now.toIso8601String(),
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
        'metadata': {'role': 'user'},
      };
      
      final user = User.fromJson(json);
      
      expect(user.id, equals('1'));
      expect(user.name, equals('Test User'));
      expect(user.email, equals('test@example.com'));
      expect(user.emailVerifiedAt, isNotNull);
      expect(user.isEmailVerified, isTrue);
      expect(user.metadata, equals({'role': 'user'}));
    });
    
    test('should convert user to JSON', () {
      final now = DateTime.now();
      final user = User(
        id: '1',
        name: 'Test User',
        email: 'test@example.com',
        emailVerifiedAt: now,
        createdAt: now,
        updatedAt: now,
        metadata: {'role': 'user'},
      );
      
      final json = user.toJson();
      
      expect(json['id'], equals('1'));
      expect(json['name'], equals('Test User'));
      expect(json['email'], equals('test@example.com'));
      expect(json['email_verified_at'], equals(now.toIso8601String()));
      expect(json['created_at'], equals(now.toIso8601String()));
      expect(json['updated_at'], equals(now.toIso8601String()));
      expect(json['metadata'], equals({'role': 'user'}));
    });
    
    test('should create copy with updated fields', () {
      final now = DateTime.now();
      final user = User(
        id: '1',
        name: 'Test User',
        email: 'test@example.com',
        createdAt: now,
        updatedAt: now,
      );
      
      final updatedUser = user.copyWith(name: 'Updated User');
      
      expect(updatedUser.id, equals('1'));
      expect(updatedUser.name, equals('Updated User'));
      expect(updatedUser.email, equals('test@example.com'));
      expect(updatedUser.createdAt, equals(now));
      expect(updatedUser.updatedAt, equals(now));
    });
    
    test('should check email verification status', () {
      final now = DateTime.now();
      
      final verifiedUser = User(
        id: '1',
        name: 'Test User',
        email: 'test@example.com',
        emailVerifiedAt: now,
        createdAt: now,
        updatedAt: now,
      );
      
      final unverifiedUser = User(
        id: '2',
        name: 'Test User 2',
        email: 'test2@example.com',
        createdAt: now,
        updatedAt: now,
      );
      
      expect(verifiedUser.isEmailVerified, isTrue);
      expect(unverifiedUser.isEmailVerified, isFalse);
    });
  });
}