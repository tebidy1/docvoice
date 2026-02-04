import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../../../lib/core/core.dart';

void main() {
  group('AudioServiceImpl Integration', () {
    late AudioServiceImpl audioService;
    
    setUpAll(() async {
      // Initialize dotenv for testing
      try {
        await dotenv.load(fileName: '.env.test');
      } catch (e) {
        // If .env.test doesn't exist, load from string
        dotenv.load(mergeWith: {
          'API_BASE_URL': 'https://test.example.com/api',
          'API_TIMEOUT': '30000',
        });
      }
    });
    
    setUp(() {
      audioService = AudioServiceImpl();
    });
    
    tearDown(() async {
      if (audioService.isInitialized) {
        await audioService.dispose();
      }
    });
    
    test('should initialize without throwing', () async {
      await audioService.initialize();
      expect(audioService.isInitialized, isTrue);
    });
    
    test('should return supported formats', () async {
      await audioService.initialize();
      
      final formats = audioService.getSupportedFormats();
      expect(formats, isNotEmpty);
      expect(formats, contains('mp3'));
      expect(formats, contains('wav'));
      expect(formats, contains('m4a'));
      expect(formats, contains('flac'));
      
      // Should return immutable list
      expect(() => formats.add('test'), throwsUnsupportedError);
    });
    
    test('should validate non-existent file correctly', () async {
      await audioService.initialize();
      
      final nonExistentFile = File('/path/to/non/existent/file.mp3');
      final result = await audioService.validateAudioFile(nonExistentFile);
      
      expect(result.isValid, isFalse);
      expect(result.errors, contains('Audio file does not exist'));
    });
    
    test('should throw when not initialized', () {
      expect(
        () => audioService.validateAudioFile(File('test.mp3')),
        throwsA(isA<StateError>()),
      );
    });
    
    test('should dispose cleanly', () async {
      await audioService.initialize();
      expect(audioService.isInitialized, isTrue);
      
      await audioService.dispose();
      expect(audioService.isDisposed, isTrue);
      expect(audioService.isInitialized, isFalse);
    });
  });
}