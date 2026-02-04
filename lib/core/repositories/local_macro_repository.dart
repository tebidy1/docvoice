import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../interfaces/abstract_repository.dart';
import '../interfaces/macro_repository.dart';
import '../dto/macro_dto.dart';
import '../../models/macro.dart';

/// Local storage implementation of MacroRepository
/// Uses SharedPreferences for persistence across platforms
class LocalMacroRepository extends AbstractLocalRepository<Macro> implements MacroRepository {
  final MacroDtoMapper _mapper = MacroDtoMapper();
  final StreamController<List<Macro>> _watchController = StreamController<List<Macro>>.broadcast();
  
  LocalMacroRepository({
    super.cacheManager,
    super.cacheStrategy,
  }) : super(storageKey: 'macros');
  
  @override
  String getEntityId(Macro entity) {
    return entity.id.toString();
  }
  
  @override
  Map<String, dynamic> toStorable(Macro entity) {
    return _mapper.fromEntity(entity).toJson();
  }
  
  @override
  Macro fromStorable(Map<String, dynamic> data) {
    return _mapper.toEntity(MacroDto(data));
  }
  
  @override
  Future<void> validateEntity(Macro entity) async {
    final result = _mapper.validateEntity(entity);
    if (!result.isValid) {
      throw ArgumentError('Invalid macro: ${result.errors.join(', ')}');
    }
  }
  
  // Storage operations
  
  @override
  Future<Map<String, dynamic>?> readFromStorage(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(key);
      if (jsonString != null) {
        return jsonDecode(jsonString) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('Error reading from storage: $e');
      return null;
    }
  }
  
  @override
  Future<void> writeToStorage(String key, Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(data);
      await prefs.setString(key, jsonString);
    } catch (e) {
      print('Error writing to storage: $e');
      rethrow;
    }
  }
  
  @override
  Future<void> deleteFromStorage(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
    } catch (e) {
      print('Error deleting from storage: $e');
      rethrow;
    }
  }
  
  @override
  Future<List<String>> getAllStorageKeys() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      return keys.where((key) => key.startsWith('${storageKey}_')).toList();
    } catch (e) {
      print('Error getting storage keys: $e');
      return [];
    }
  }
  
  // Base repository implementations
  
  @override
  Future<Macro?> fetchById(String id) async {
    try {
      final key = getStorageKey(id);
      final data = await readFromStorage(key);
      if (data != null) {
        return fromStorable(data);
      }
      return null;
    } catch (e) {
      print('Error fetching macro by id: $e');
      return null;
    }
  }
  
  @override
  Future<List<Macro>> fetchAll() async {
    try {
      final keys = await getAllStorageKeys();
      final macros = <Macro>[];
      
      for (final key in keys) {
        final data = await readFromStorage(key);
        if (data != null) {
          try {
            final macro = fromStorable(data);
            macros.add(macro);
          } catch (e) {
            print('Error deserializing macro from key $key: $e');
            // Continue with other macros
          }
        }
      }
      
      // Sort by creation date (newest first)
      macros.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return macros;
    } catch (e) {
      print('Error fetching all macros: $e');
      return [];
    }
  }
  
  @override
  Future<List<Macro>> fetchPaginated({required int offset, required int limit}) async {
    try {
      final allMacros = await fetchAll();
      final endIndex = (offset + limit).clamp(0, allMacros.length);
      if (offset >= allMacros.length) {
        return [];
      }
      return allMacros.sublist(offset, endIndex);
    } catch (e) {
      print('Error fetching paginated macros: $e');
      return [];
    }
  }
  
  @override
  Future<List<Macro>> searchEntities(String query) async {
    try {
      final allMacros = await fetchAll();
      final lowerQuery = query.toLowerCase();
      
      return allMacros.where((macro) {
        return macro.trigger.toLowerCase().contains(lowerQuery) ||
               macro.content.toLowerCase().contains(lowerQuery) ||
               macro.category.toLowerCase().contains(lowerQuery);
      }).toList();
    } catch (e) {
      print('Error searching macros: $e');
      return [];
    }
  }
  
  @override
  Future<Macro> createEntity(Macro entity) async {
    try {
      // Generate new ID if not set
      if (entity.id == 0) {
        entity.id = await _generateNewId();
      }
      
      // Set creation time
      entity.createdAt = DateTime.now();
      
      final key = getStorageKey(entity.id.toString());
      await writeToStorage(key, toStorable(entity));
      
      // Notify watchers
      _notifyWatchers();
      
      return entity;
    } catch (e) {
      print('Error creating macro: $e');
      rethrow;
    }
  }
  
  @override
  Future<Macro> updateEntity(Macro entity) async {
    try {
      final key = getStorageKey(entity.id.toString());
      
      // Check if entity exists
      final existing = await readFromStorage(key);
      if (existing == null) {
        throw Exception('Macro with id ${entity.id} not found');
      }
      
      await writeToStorage(key, toStorable(entity));
      
      // Notify watchers
      _notifyWatchers();
      
      return entity;
    } catch (e) {
      print('Error updating macro: $e');
      rethrow;
    }
  }
  
  @override
  Future<void> deleteEntity(String id) async {
    try {
      final key = getStorageKey(id);
      await deleteFromStorage(key);
      
      // Notify watchers
      _notifyWatchers();
    } catch (e) {
      print('Error deleting macro: $e');
      rethrow;
    }
  }
  
  // MacroRepository specific implementations
  
  @override
  Future<List<Macro>> getByCategory(String category) async {
    try {
      final allMacros = await fetchAll();
      return allMacros.where((macro) => macro.category == category).toList();
    } catch (e) {
      print('Error getting macros by category: $e');
      return [];
    }
  }
  
  @override
  Future<List<Macro>> getFavorites() async {
    try {
      final allMacros = await fetchAll();
      return allMacros.where((macro) => macro.isFavorite).toList();
    } catch (e) {
      print('Error getting favorite macros: $e');
      return [];
    }
  }
  
  @override
  Future<List<Macro>> getMostUsed({int limit = 10}) async {
    try {
      final allMacros = await fetchAll();
      
      // Sort by usage count (descending) then by last used (descending)
      allMacros.sort((a, b) {
        final usageComparison = b.usageCount.compareTo(a.usageCount);
        if (usageComparison != 0) return usageComparison;
        
        final aLastUsed = a.lastUsed ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bLastUsed = b.lastUsed ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bLastUsed.compareTo(aLastUsed);
      });
      
      return allMacros.take(limit).toList();
    } catch (e) {
      print('Error getting most used macros: $e');
      return [];
    }
  }
  
  @override
  Future<void> toggleFavorite(String id) async {
    try {
      final macro = await fetchById(id);
      if (macro != null) {
        macro.isFavorite = !macro.isFavorite;
        await updateEntity(macro);
      } else {
        throw Exception('Macro with id $id not found');
      }
    } catch (e) {
      print('Error toggling favorite: $e');
      rethrow;
    }
  }
  
  @override
  Future<void> incrementUsage(String id) async {
    try {
      final macro = await fetchById(id);
      if (macro != null) {
        macro.usageCount++;
        macro.lastUsed = DateTime.now();
        await updateEntity(macro);
      } else {
        print('Warning: Macro with id $id not found for usage increment');
      }
    } catch (e) {
      print('Error incrementing usage: $e');
      // Don't rethrow - usage tracking is not critical
    }
  }
  
  @override
  Future<List<String>> getCategories() async {
    try {
      final allMacros = await fetchAll();
      final categories = allMacros.map((macro) => macro.category).toSet().toList();
      categories.sort();
      return categories;
    } catch (e) {
      print('Error getting categories: $e');
      return [];
    }
  }
  
  @override
  Future<String?> findExpansion(String text) async {
    try {
      final allMacros = await fetchAll();
      
      // Sort by trigger length descending to match longest phrases first
      allMacros.sort((a, b) => b.trigger.length.compareTo(a.trigger.length));
      
      final normalizedText = text.toLowerCase();
      
      for (final macro in allMacros) {
        if (normalizedText.contains(macro.trigger.toLowerCase())) {
          // Increment usage count
          await incrementUsage(macro.id.toString());
          return macro.content;
        }
      }
      
      return null;
    } catch (e) {
      print('Error finding expansion: $e');
      return null;
    }
  }
  
  @override
  Future<List<Macro>> searchByTrigger(String trigger) async {
    try {
      final allMacros = await fetchAll();
      final lowerTrigger = trigger.toLowerCase();
      
      return allMacros.where((macro) {
        return macro.trigger.toLowerCase().contains(lowerTrigger);
      }).toList();
    } catch (e) {
      print('Error searching by trigger: $e');
      return [];
    }
  }
  
  @override
  Future<String> getMacrosAsJson() async {
    try {
      final macros = await fetchAll();
      final List<Map<String, dynamic>> jsonList = macros.map((m) => {
        'id': m.id,
        'trigger': m.trigger,
        'content': m.content,
        'category': m.category,
      }).toList();
      return jsonEncode(jsonList);
    } catch (e) {
      print('Error getting macros as JSON: $e');
      return "[]";
    }
  }
  
  @override
  Future<void> sync() async {
    // For local repository, sync is a no-op
    // This could be used to trigger cache refresh or validation
    print('Local repository sync requested - no action needed');
  }
  
  @override
  Stream<List<Macro>> watch() {
    // Return the broadcast stream and immediately emit current data
    _notifyWatchers();
    return _watchController.stream;
  }
  
  // Helper methods
  
  Future<int> _generateNewId() async {
    try {
      final allMacros = await fetchAll();
      if (allMacros.isEmpty) {
        return 1;
      }
      
      final maxId = allMacros.map((m) => m.id).reduce((a, b) => a > b ? a : b);
      return maxId + 1;
    } catch (e) {
      print('Error generating new ID: $e');
      // Fallback to timestamp-based ID
      return DateTime.now().millisecondsSinceEpoch;
    }
  }
  
  void _notifyWatchers() {
    // Emit current data to watchers asynchronously
    fetchAll().then((macros) {
      if (!_watchController.isClosed) {
        _watchController.add(macros);
      }
    }).catchError((e) {
      print('Error notifying watchers: $e');
      if (!_watchController.isClosed) {
        _watchController.addError(e);
      }
    });
  }
  
  /// Clean up resources
  void dispose() {
    _watchController.close();
  }
}