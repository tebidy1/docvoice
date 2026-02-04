import 'package:flutter_test/flutter_test.dart';
import 'package:scribeflow/core/repositories/repositories.dart';
import 'package:scribeflow/core/interfaces/cache_strategy.dart';
import 'package:scribeflow/core/interfaces/macro_repository.dart';
import 'package:scribeflow/services/api_service.dart';
import 'package:scribeflow/models/macro.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:scribeflow/core/repositories/repositories.dart';
import 'package:scribeflow/core/interfaces/cache_strategy.dart';
import 'package:scribeflow/core/interfaces/macro_repository.dart';
import 'package:scribeflow/models/macro.dart';

void main() {
  group('Concrete Repository Tests', () {
    test('LocalMacroRepository can be instantiated', () {
      expect(() {
        final repository = LocalMacroRepository();
        expect(repository, isNotNull);
        expect(repository, isA<LocalMacroRepository>());
      }, returnsNormally);
    });
    
    test('LocalMacroRepository can be instantiated with cache strategy', () {
      expect(() {
        final repository = LocalMacroRepository(
          cacheStrategy: RepositoryCacheStrategies.macroStrategy<Macro>(),
        );
        expect(repository, isNotNull);
        expect(repository, isA<LocalMacroRepository>());
      }, returnsNormally);
    });
    
    test('LocalMacroRepository implements MacroRepository interface', () {
      final localRepo = LocalMacroRepository();
      expect(localRepo, isA<MacroRepository>());
    });
    
    test('LocalMacroRepository has correct storage key', () {
      final repository = LocalMacroRepository();
      expect(repository.storageKey, equals('macros'));
    });
    
    test('LocalMacroRepository can generate entity ID', () {
      final repository = LocalMacroRepository();
      final macro = Macro();
      macro.id = 123;
      
      final entityId = repository.getEntityId(macro);
      expect(entityId, equals('123'));
    });
    
    test('LocalMacroRepository can convert to/from storable format', () {
      final repository = LocalMacroRepository();
      final macro = Macro();
      macro.id = 1;
      macro.trigger = 'test';
      macro.content = 'test content';
      macro.category = 'Test';
      macro.createdAt = DateTime.now();
      
      // Convert to storable format
      final storable = repository.toStorable(macro);
      expect(storable, isA<Map<String, dynamic>>());
      expect(storable['trigger'], equals('test'));
      expect(storable['content'], equals('test content'));
      
      // Convert back from storable format
      final restored = repository.fromStorable(storable);
      expect(restored.trigger, equals(macro.trigger));
      expect(restored.content, equals(macro.content));
      expect(restored.category, equals(macro.category));
    });
    
    test('Cache strategies can be created', () {
      expect(() {
        final macroStrategy = RepositoryCacheStrategies.macroStrategy<Macro>();
        expect(macroStrategy, isNotNull);
        expect(macroStrategy, isA<CacheStrategy<Macro>>());
      }, returnsNormally);
      
      expect(() {
        final settingsStrategy = RepositoryCacheStrategies.settingsStrategy<Macro>();
        expect(settingsStrategy, isNotNull);
        expect(settingsStrategy, isA<CacheStrategy<Macro>>());
      }, returnsNormally);
      
      expect(() {
        final inboxStrategy = RepositoryCacheStrategies.inboxNoteStrategy<Macro>();
        expect(inboxStrategy, isNotNull);
        expect(inboxStrategy, isA<CacheStrategy<Macro>>());
      }, returnsNormally);
    });
    
    test('Memory cache manager can be created', () {
      expect(() {
        final cacheManager = MemoryCacheManager<Macro>();
        expect(cacheManager, isNotNull);
        expect(cacheManager, isA<CacheManager<Macro>>());
      }, returnsNormally);
    });
  });
}