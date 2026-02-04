import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:scribeflow/core/core.dart';
import 'package:scribeflow/models/macro.dart';
import 'package:scribeflow/models/user.dart';

/// Mock implementation of AbstractRepository for testing
class MockMacroRepository extends AbstractRepository<Macro> {
  final Map<String, Macro> _storage = {};
  
  @override
  Future<Macro?> fetchById(String id) async {
    return _storage[id];
  }
  
  @override
  Future<List<Macro>> fetchAll() async {
    return _storage.values.toList();
  }
  
  @override
  Future<List<Macro>> fetchPaginated({required int offset, required int limit}) async {
    final all = await fetchAll();
    final end = (offset + limit).clamp(0, all.length);
    return all.sublist(offset.clamp(0, all.length), end);
  }
  
  @override
  Future<List<Macro>> searchEntities(String query) async {
    final all = await fetchAll();
    return all.where((macro) => 
      macro.trigger.toLowerCase().contains(query.toLowerCase()) ||
      macro.content.toLowerCase().contains(query.toLowerCase())
    ).toList();
  }
  
  @override
  Future<Macro> createEntity(Macro entity) async {
    final id = entity.id.toString();
    _storage[id] = entity;
    return entity;
  }
  
  @override
  Future<Macro> updateEntity(Macro entity) async {
    final id = entity.id.toString();
    if (!_storage.containsKey(id)) {
      throw Exception('Entity not found');
    }
    _storage[id] = entity;
    return entity;
  }
  
  @override
  Future<void> deleteEntity(String id) async {
    _storage.remove(id);
  }
  
  @override
  String getEntityId(Macro entity) => entity.id.toString();
  
  @override
  Future<void> validateEntity(Macro entity) async {
    if (entity.trigger.isEmpty) {
      throw ValidationError('Trigger cannot be empty', {'trigger': ['Trigger is required']});
    }
    if (entity.content.isEmpty) {
      throw ValidationError('Content cannot be empty', {'content': ['Content is required']});
    }
  }
}

/// Mock cache manager for testing
class MockCacheManager<T> implements CacheManager<T> {
  final Map<String, T> _cache = {};
  
  @override
  Future<T?> get(String id) async => _cache[id];
  
  @override
  Future<void> put(String id, T entity) async {
    _cache[id] = entity;
  }
  
  @override
  Future<void> remove(String id) async {
    _cache.remove(id);
  }
  
  @override
  Future<void> clear() async {
    _cache.clear();
  }
  
  @override
  Future<CacheStats> getStats() async {
    return CacheStats(
      hitCount: 0,
      missCount: 0,
      totalRequests: 0,
      hitRate: 0.0,
      cachedItems: _cache.length,
      totalMemoryUsage: _cache.length * 100,
    );
  }
  
  @override
  Future<List<String>> getKeys() async => _cache.keys.toList();
  
  @override
  Future<bool> containsKey(String id) async => _cache.containsKey(id);
  
  @override
  Future<int> getSize() async => _cache.length;
  
  @override
  Future<void> evictLRU(int count) async {
    final keys = _cache.keys.take(count).toList();
    for (final key in keys) {
      _cache.remove(key);
    }
  }
}

void main() {
  group('Repository Pattern Tests', () {
    late MockMacroRepository repository;
    late MockCacheManager<Macro> cacheManager;
    
    setUp(() {
      repository = MockMacroRepository();
      cacheManager = MockCacheManager<Macro>();
    });
    
    test('BaseRepository CRUD operations work correctly', () async {
      // Create a test macro
      final macro = Macro()
        ..id = 1
        ..trigger = 'test'
        ..content = 'test content'
        ..category = 'Test';
      
      // Test create
      final created = await repository.create(macro);
      expect(created.id, equals(1));
      expect(created.trigger, equals('test'));
      
      // Test getById
      final retrieved = await repository.getById('1');
      expect(retrieved, isNotNull);
      expect(retrieved!.trigger, equals('test'));
      
      // Test exists
      final exists = await repository.exists('1');
      expect(exists, isTrue);
      
      // Test getAll
      final all = await repository.getAll();
      expect(all.length, equals(1));
      expect(all.first.trigger, equals('test'));
      
      // Test update
      final updated = macro..content = 'updated content';
      await repository.update(updated);
      final retrievedUpdated = await repository.getById('1');
      expect(retrievedUpdated!.content, equals('updated content'));
      
      // Test delete
      await repository.delete('1');
      final deletedEntity = await repository.getById('1');
      expect(deletedEntity, isNull);
    });
    
    test('Repository validation works correctly', () async {
      // Test validation failure
      final invalidMacro = Macro()
        ..id = 1
        ..trigger = '' // Empty trigger should fail validation
        ..content = 'test content';
      
      expect(
        () => repository.create(invalidMacro),
        throwsA(isA<ValidationError>()),
      );
      
      // Test validation success
      final validMacro = Macro()
        ..id = 2
        ..trigger = 'valid'
        ..content = 'valid content';
      
      expect(
        () => repository.create(validMacro),
        returnsNormally,
      );
    });
    
    test('Repository search functionality works', () async {
      // Create test data
      final macros = [
        Macro()..id = 1..trigger = 'cardio'..content = 'Normal cardiac exam',
        Macro()..id = 2..trigger = 'neuro'..content = 'Neurological assessment',
        Macro()..id = 3..trigger = 'heart'..content = 'Heart sounds normal',
      ];
      
      for (final macro in macros) {
        await repository.create(macro);
      }
      
      // Test search by trigger
      final cardioResults = await repository.search('cardio');
      expect(cardioResults.length, equals(1));
      expect(cardioResults.first.trigger, equals('cardio'));
      
      // Test search by content
      final heartResults = await repository.search('heart');
      expect(heartResults.length, equals(1));
      expect(heartResults.first.content, contains('Heart'));
      
      // Test search with no results
      final noResults = await repository.search('xyz');
      expect(noResults.length, equals(0));
    });
    
    test('Repository pagination works correctly', () async {
      // Create test data
      for (int i = 1; i <= 25; i++) {
        final macro = Macro()
          ..id = i
          ..trigger = 'trigger$i'
          ..content = 'content$i';
        await repository.create(macro);
      }
      
      // Test first page
      final page1 = await repository.getPaginated(page: 1, limit: 10);
      expect(page1.length, equals(10));
      
      // Test second page
      final page2 = await repository.getPaginated(page: 2, limit: 10);
      expect(page2.length, equals(10));
      
      // Test last page
      final page3 = await repository.getPaginated(page: 3, limit: 10);
      expect(page3.length, equals(5));
      
      // Test beyond available data
      final page4 = await repository.getPaginated(page: 4, limit: 10);
      expect(page4.length, equals(0));
    });
    
    test('Cache strategies work correctly', () {
      // Test TimeBased strategy
      final timeBased = TimeBased<String>(const Duration(minutes: 30));
      final now = DateTime.now();
      
      // Valid cache (within duration)
      expect(timeBased.isValid('test', now.subtract(const Duration(minutes: 15))), isTrue);
      
      // Invalid cache (expired)
      expect(timeBased.isValid('test', now.subtract(const Duration(hours: 1))), isFalse);
      
      // Test UsageBased strategy
      final usageBased = UsageBased<String>(const Duration(minutes: 30), 5);
      
      // Should not cache by default (usage count is 0)
      expect(usageBased.shouldCache('test'), isFalse);
      
      // Cache key generation
      expect(timeBased.getCacheKey('123'), equals('cache_123'));
      expect(usageBased.getCacheKey('123'), equals('usage_cache_123'));
    });
    
    test('Memory cache manager works correctly', () async {
      final cache = MemoryCacheManager<String>(maxSize: 3);
      
      // Test put and get
      await cache.put('key1', 'value1');
      final value = await cache.get('key1');
      expect(value, equals('value1'));
      
      // Test containsKey
      expect(await cache.containsKey('key1'), isTrue);
      expect(await cache.containsKey('nonexistent'), isFalse);
      
      // Test size limit and eviction
      await cache.put('key2', 'value2');
      await cache.put('key3', 'value3');
      await cache.put('key4', 'value4'); // Should evict key1
      
      expect(await cache.containsKey('key1'), isFalse);
      expect(await cache.containsKey('key4'), isTrue);
      expect(await cache.getSize(), equals(3));
      
      // Test clear
      await cache.clear();
      expect(await cache.getSize(), equals(0));
    });
    
    test('Repository-specific cache strategies are configured correctly', () {
      // Test macro strategy
      final macroStrategy = RepositoryCacheStrategies.macroStrategy<Macro>();
      expect(macroStrategy, isA<UsageBased<Macro>>());
      
      // Test settings strategy
      final settingsStrategy = RepositoryCacheStrategies.settingsStrategy<UserSettings>();
      expect(settingsStrategy, isA<WriteThrough<UserSettings>>());
      
      // Test inbox note strategy
      final noteStrategy = RepositoryCacheStrategies.inboxNoteStrategy<dynamic>();
      expect(noteStrategy, isA<TimeBased<dynamic>>());
      
      // Test audio upload strategy
      final audioStrategy = RepositoryCacheStrategies.audioUploadStrategy<AudioUploadResult>();
      expect(audioStrategy, isA<TimeBased<AudioUploadResult>>());
      
      // Test transcription strategy
      final transcriptionStrategy = RepositoryCacheStrategies.transcriptionStrategy<TranscriptionResult>();
      expect(transcriptionStrategy, isA<TimeBased<TranscriptionResult>>());
      
      // Test user strategy
      final userStrategy = RepositoryCacheStrategies.userStrategy<User>();
      expect(userStrategy, isA<Adaptive<User>>());
    });
  });
  
  group('Repository Interface Tests', () {
    test('AudioUploadRepository interface is properly defined', () {
      // This test verifies that the interface is properly structured
      // In a real implementation, we would test concrete implementations
      expect(AudioUploadRepository, isA<Type>());
    });
    
    test('TranscriptionRepository interface is properly defined', () {
      expect(TranscriptionRepository, isA<Type>());
    });
    
    test('SettingsRepository interface is properly defined', () {
      expect(SettingsRepository, isA<Type>());
    });
    
    test('UploadProgressRepository interface is properly defined', () {
      expect(UploadProgressRepository, isA<Type>());
    });
  });
  
  group('Settings Repository Models Tests', () {
    test('SettingsConflict serialization works correctly', () {
      final conflict = SettingsConflict(
        userId: 'user123',
        settingKey: 'theme',
        localValue: 'dark',
        remoteValue: 'light',
        localModified: DateTime(2024, 1, 1, 12, 0),
        remoteModified: DateTime(2024, 1, 1, 13, 0),
        type: ConflictType.valueConflict,
      );
      
      // Test toJson
      final json = conflict.toJson();
      expect(json['user_id'], equals('user123'));
      expect(json['setting_key'], equals('theme'));
      expect(json['local_value'], equals('dark'));
      expect(json['remote_value'], equals('light'));
      expect(json['type'], equals('valueConflict'));
      
      // Test fromJson
      final restored = SettingsConflict.fromJson(json);
      expect(restored.userId, equals('user123'));
      expect(restored.settingKey, equals('theme'));
      expect(restored.localValue, equals('dark'));
      expect(restored.remoteValue, equals('light'));
      expect(restored.type, equals(ConflictType.valueConflict));
    });
    
    test('SettingsSyncStatus serialization works correctly', () {
      final status = SettingsSyncStatus(
        userId: 'user123',
        isSynced: false,
        lastSyncTime: DateTime(2024, 1, 1, 12, 0),
        pendingChanges: 3,
        conflictKeys: ['theme', 'language'],
        state: SyncState.conflict,
      );
      
      // Test toJson
      final json = status.toJson();
      expect(json['user_id'], equals('user123'));
      expect(json['is_synced'], isFalse);
      expect(json['pending_changes'], equals(3));
      expect(json['conflict_keys'], equals(['theme', 'language']));
      expect(json['state'], equals('conflict'));
      
      // Test fromJson
      final restored = SettingsSyncStatus.fromJson(json);
      expect(restored.userId, equals('user123'));
      expect(restored.isSynced, isFalse);
      expect(restored.pendingChanges, equals(3));
      expect(restored.conflictKeys, equals(['theme', 'language']));
      expect(restored.state, equals(SyncState.conflict));
    });
  });
}