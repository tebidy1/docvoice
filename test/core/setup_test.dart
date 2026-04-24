import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:soutnote/core/network/api_client.dart';
import 'package:soutnote/core/services/auth_service.dart';
import 'package:soutnote/core/di/service_locator.dart';

void main() {
  setUpAll(() async {
    try {
      await dotenv.load(fileName: ".env");
    } catch (e) {
      try {
        await dotenv.load(fileName: ".env.test");
      } catch (e) {
        dotenv.env['API_BASE_URL'] = 'https://test.example.com/api';
        dotenv.env['API_TIMEOUT'] = '30000';
      }
    }
  });

  group('Core Setup Tests', () {
    test('ServiceLocator initializes without error', () async {
      ServiceLocator.registerSingleton<ApiClient>(ApiClient());
      ServiceLocator.registerSingleton<AuthService>(AuthService());

      expect(ServiceLocator.isRegistered<ApiClient>(), isTrue);
      expect(ServiceLocator.isRegistered<AuthService>(), isTrue);

      await ServiceLocator.reset();
    });

    test('Property test generators work', () {
      final random = Random(42);

      for (int i = 0; i < 10; i++) {
        final intValue = random.nextInt(100) + 1;
        expect(intValue, greaterThanOrEqualTo(1));
        expect(intValue, lessThanOrEqualTo(101));
      }
    });
  });
}
