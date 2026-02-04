import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:scribeflow/core/core.dart';
import 'package:scribeflow/services/api_service.dart';
import 'package:scribeflow/services/auth_service.dart';

void main() {
  setUpAll(() async {
    // Initialize dotenv for tests
    try {
      await dotenv.load(fileName: ".env");
    } catch (e) {
      // If .env doesn't exist, load test env or use defaults
      try {
        await dotenv.load(fileName: ".env.test");
      } catch (e) {
        // Set default values for testing
        dotenv.env['API_BASE_URL'] = 'https://test.example.com/api';
        dotenv.env['API_TIMEOUT'] = '30000';
      }
    }
  });
  
  group('Core Setup Tests', () {
    test('ServiceLocator initializes without error', () async {
      // For unit tests, we'll just test the registration without full initialization
      // since ApiService.init() requires platform plugins
      
      // Register services manually for testing
      ServiceLocator.registerSingleton<ApiService>(ApiService());
      ServiceLocator.registerSingleton<AuthService>(AuthService());
      
      // Verify core services are registered
      expect(ServiceLocator.isRegistered<ApiService>(), isTrue);
      expect(ServiceLocator.isRegistered<AuthService>(), isTrue);
      
      // Clean up
      await ServiceLocator.reset();
    });
    
    test('DTO mappers work correctly', () {
      final mapper = MacroDtoMapper();
      
      // Test DTO to entity mapping
      final dto = MacroDto({
        'id': 1,
        'trigger': 'test trigger',
        'content': 'test content',
        'category': 'Test',
        'is_favorite': true,
        'usage_count': 5,
        'is_ai_macro': false,
        'created_at': DateTime.now().toIso8601String(),
      });
      
      final entity = mapper.toEntity(dto);
      
      expect(entity.id, equals(1));
      expect(entity.trigger, equals('test trigger'));
      expect(entity.content, equals('test content'));
      expect(entity.category, equals('Test'));
      expect(entity.isFavorite, isTrue);
      expect(entity.usageCount, equals(5));
      expect(entity.isAiMacro, isFalse);
    });
    
    test('Error handler converts exceptions correctly', () {
      final handler = ErrorHandler();
      
      // Test API exception conversion
      final apiException = ApiException('Test error', 400);
      final appError = handler.convertToAppError(apiException);
      
      expect(appError, isA<NetworkError>());
      expect(appError.message, equals('Test error'));
      
      final networkError = appError as NetworkError;
      expect(networkError.statusCode, equals(400));
    });
    
    test('Property test generators work', () {
      // Test generators directly instead of using PropertyTest.property
      final intGen = Gen.integer(min: 1, max: 100);
      final stringGen = Gen.nonEmptyString(maxLength: 50);
      
      // Generate some values and verify they meet constraints
      final random = Random(42); // Fixed seed for reproducible tests
      
      for (int i = 0; i < 10; i++) {
        final intValue = intGen.generate(random);
        expect(intValue, greaterThanOrEqualTo(1));
        expect(intValue, lessThanOrEqualTo(100));
        
        final stringValue = stringGen.generate(random);
        expect(stringValue.isNotEmpty, isTrue);
        expect(stringValue.length, lessThanOrEqualTo(50));
      }
    });
  });
}