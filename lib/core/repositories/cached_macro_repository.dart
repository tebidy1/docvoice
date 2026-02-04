import 'dart:async';
import '../interfaces/macro_repository.dart';
import '../interfaces/cache_strategy.dart';
import '../../models/macro.dart';
import 'api_macro_repository.dart';
import 'local_macro_repository.dart';

/// Cached implementation of MacroRepository
/// Combines API and local storage with intelligent caching strategies
class CachedMacroRepository implements MacroRepository {
  final ApiMacroRepository _apiRepository;
  final LocalMacroRepository _localRepository;
  final CacheStrategy<Macro> _cacheStrategy;
  final Duration _syncInterval;
  
  Timer? _syncTimer;
  bool _isOnline = true;
  final StreamController<List<Macro>> _watchController = StreamController<List<Macro>>.broadcast();
  
  CachedMacroRepository({
    required ApiMacroRepository apiRepository,
    required LocalMacroRepository localRepository,
    CacheStrategy<Macro>? cacheStrategy,
    Duration syncInterval = const Duration(minutes: 5),
  }) : _apiRepository = apiRepository,
       _localRepository = localRepository,
       _cacheStrategy = cacheStrategy ?? RepositoryCacheStrategies.macroStrategy<Macro>(),
       _syncInterval = syncInterval {
    _startPeriodicSync();
    _setupWatching();
  }
  
  // Connectivity management
  
  void setOnlineStatus(bool isOnline) {
    _isOnline = isOnline;
    if (isOnline) {
      _performSync();
    }
  }
  
  // Base repository implementations with cache-first strategy
  
  @override
  Future<List<Macro>> getAll() async {
    try {
      if (_isOnline) {
        // Try API first when online
        final apiMacros = await _apiRepository.getAll();
        if (apiMacros.isNotEmpty) {
          // Update local cache
          await _updateLocalCache(apiMacros);
          return apiMacros;
        }
      }
      
      // Fallback to local storage
      return await _localRepository.getAll();
    } catch (e) {
      print('Error in getAll, falling back to local: $e');
      return await _localRepository.getAll();
    }
  }
  
  @override
  Future<Macro?> getById(String id) async {
    try {
      // Try local cache first for better performance
      final localMacro = await _localRepository.getById(id);
      if (localMacro != null && _cacheStrategy.isValid(localMacro, DateTime.now())) {
        return localMacro;
      }
      
      if (_isOnline) {
        // Try API if cache miss or invalid
        final apiMacro = await _apiRepository.getById(id);
        if (apiMacro != null) {
          // Update local cache
          await _localRepository.update(apiMacro);
          return apiMacro;
        }
      }
      
      // Return stale local data if available
      return localMacro;
    } catch (e) {
      print('Error in getById, falling back to local: $e');
      return await _localRepository.getById(id);
    }
  }
  
  @override
  Future<Macro> create(Macro entity) async {
    try {
      if (_isOnline) {
        // Create in API first
        final apiMacro = await _apiRepository.create(entity);
        
        // Update local cache
        await _localRepository.create(apiMacro);
        
        _notifyWatchers();
        return apiMacro;
      } else {
        // Create locally when offline
        final localMacro = await _localRepository.create(entity);
        
        // Mark for sync when online
        await _markForSync(localMacro, 'create');
        
        _notifyWatchers();
        return localMacro;
      }
    } catch (e) {
      print('Error creating in API, saving locally: $e');
      
      // Fallback to local creation
      final localMacro = await _localRepository.create(entity);
      await _markForSync(localMacro, 'create');
      
      _notifyWatchers();
      return localMacro;
    }
  }
  
  @override
  Future<Macro> update(Macro entity) async {
    try {
      if (_isOnline) {
        // Update in API first
        final apiMacro = await _apiRepository.update(entity);
        
        // Update local cache
        await _localRepository.update(apiMacro);
        
        _notifyWatchers();
        return apiMacro;
      } else {
        // Update locally when offline
        final localMacro = await _localRepository.update(entity);
        
        // Mark for sync when online
        await _markForSync(localMacro, 'update');
        
        _notifyWatchers();
        return localMacro;
      }
    } catch (e) {
      print('Error updating in API, saving locally: $e');
      
      // Fallback to local update
      final localMacro = await _localRepository.update(entity);
      await _markForSync(localMacro, 'update');
      
      _notifyWatchers();
      return localMacro;
    }
  }
  
  @override
  Future<void> delete(String id) async {
    try {
      if (_isOnline) {
        // Delete from API first
        await _apiRepository.delete(id);
        
        // Delete from local cache
        await _localRepository.delete(id);
        
        _notifyWatchers();
      } else {
        // Mark for deletion when offline
        await _markForSync(await _localRepository.getById(id), 'delete');
        
        // Delete locally
        await _localRepository.delete(id);
        
        _notifyWatchers();
      }
    } catch (e) {
      print('Error deleting from API, marking for sync: $e');
      
      // Mark for sync and delete locally
      await _markForSync(await _localRepository.getById(id), 'delete');
      await _localRepository.delete(id);
      
      _notifyWatchers();
    }
  }
  
  @override
  Future<bool> exists(String id) async {
    final macro = await getById(id);
    return macro != null;
  }
  
  @override
  Future<List<Macro>> getPaginated({int page = 1, int limit = 20}) async {
    try {
      if (_isOnline) {
        return await _apiRepository.getPaginated(page: page, limit: limit);
      } else {
        return await _localRepository.getPaginated(page: page, limit: limit);
      }
    } catch (e) {
      print('Error in getPaginated, falling back to local: $e');
      return await _localRepository.getPaginated(page: page, limit: limit);
    }
  }
  
  @override
  Future<List<Macro>> search(String query) async {
    try {
      if (_isOnline) {
        final apiResults = await _apiRepository.search(query);
        if (apiResults.isNotEmpty) {
          return apiResults;
        }
      }
      
      // Fallback to local search
      return await _localRepository.search(query);
    } catch (e) {
      print('Error in search, falling back to local: $e');
      return await _localRepository.search(query);
    }
  }
  
  @override
  Stream<List<Macro>> watch() {
    return _watchController.stream;
  }
  
  // MacroRepository specific implementations
  
  @override
  Future<List<Macro>> getByCategory(String category) async {
    try {
      if (_isOnline) {
        final apiMacros = await _apiRepository.getByCategory(category);
        if (apiMacros.isNotEmpty) {
          return apiMacros;
        }
      }
      
      return await _localRepository.getByCategory(category);
    } catch (e) {
      print('Error getting by category, falling back to local: $e');
      return await _localRepository.getByCategory(category);
    }
  }
  
  @override
  Future<List<Macro>> getFavorites() async {
    try {
      if (_isOnline) {
        final apiFavorites = await _apiRepository.getFavorites();
        if (apiFavorites.isNotEmpty) {
          return apiFavorites;
        }
      }
      
      return await _localRepository.getFavorites();
    } catch (e) {
      print('Error getting favorites, falling back to local: $e');
      return await _localRepository.getFavorites();
    }
  }
  
  @override
  Future<List<Macro>> getMostUsed({int limit = 10}) async {
    try {
      if (_isOnline) {
        final apiMostUsed = await _apiRepository.getMostUsed(limit: limit);
        if (apiMostUsed.isNotEmpty) {
          return apiMostUsed;
        }
      }
      
      return await _localRepository.getMostUsed(limit: limit);
    } catch (e) {
      print('Error getting most used, falling back to local: $e');
      return await _localRepository.getMostUsed(limit: limit);
    }
  }
  
  @override
  Future<void> toggleFavorite(String id) async {
    try {
      if (_isOnline) {
        await _apiRepository.toggleFavorite(id);
        
        // Update local cache
        final macro = await _localRepository.getById(id);
        if (macro != null) {
          macro.isFavorite = !macro.isFavorite;
          await _localRepository.update(macro);
        }
      } else {
        // Toggle locally and mark for sync
        await _localRepository.toggleFavorite(id);
        final macro = await _localRepository.getById(id);
        if (macro != null) {
          await _markForSync(macro, 'update');
        }
      }
      
      _notifyWatchers();
    } catch (e) {
      print('Error toggling favorite in API, updating locally: $e');
      
      await _localRepository.toggleFavorite(id);
      final macro = await _localRepository.getById(id);
      if (macro != null) {
        await _markForSync(macro, 'update');
      }
      
      _notifyWatchers();
    }
  }
  
  @override
  Future<void> incrementUsage(String id) async {
    try {
      // Always update locally first for immediate feedback
      await _localRepository.incrementUsage(id);
      
      if (_isOnline) {
        // Try to sync with API
        await _apiRepository.incrementUsage(id);
      } else {
        // Mark for sync when online
        final macro = await _localRepository.getById(id);
        if (macro != null) {
          await _markForSync(macro, 'update');
        }
      }
    } catch (e) {
      print('Error incrementing usage in API: $e');
      // Local update already done, just mark for sync
      final macro = await _localRepository.getById(id);
      if (macro != null) {
        await _markForSync(macro, 'update');
      }
    }
  }
  
  @override
  Future<List<String>> getCategories() async {
    try {
      if (_isOnline) {
        final apiCategories = await _apiRepository.getCategories();
        if (apiCategories.isNotEmpty) {
          return apiCategories;
        }
      }
      
      return await _localRepository.getCategories();
    } catch (e) {
      print('Error getting categories, falling back to local: $e');
      return await _localRepository.getCategories();
    }
  }
  
  @override
  Future<String?> findExpansion(String text) async {
    try {
      // Try local first for better performance
      final localExpansion = await _localRepository.findExpansion(text);
      if (localExpansion != null) {
        return localExpansion;
      }
      
      if (_isOnline) {
        // Try API if not found locally
        final apiExpansion = await _apiRepository.findExpansion(text);
        if (apiExpansion != null) {
          return apiExpansion;
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
      if (_isOnline) {
        final apiResults = await _apiRepository.searchByTrigger(trigger);
        if (apiResults.isNotEmpty) {
          return apiResults;
        }
      }
      
      return await _localRepository.searchByTrigger(trigger);
    } catch (e) {
      print('Error searching by trigger, falling back to local: $e');
      return await _localRepository.searchByTrigger(trigger);
    }
  }
  
  @override
  Future<String> getMacrosAsJson() async {
    try {
      if (_isOnline) {
        return await _apiRepository.getMacrosAsJson();
      } else {
        return await _localRepository.getMacrosAsJson();
      }
    } catch (e) {
      print('Error getting macros as JSON, falling back to local: $e');
      return await _localRepository.getMacrosAsJson();
    }
  }
  
  @override
  Future<void> sync() async {
    if (!_isOnline) {
      print('Cannot sync while offline');
      return;
    }
    
    await _performSync();
  }
  
  // Private helper methods
  
  Future<void> _updateLocalCache(List<Macro> macros) async {
    try {
      // Clear existing cache and update with fresh data
      final existingMacros = await _localRepository.getAll();
      
      // Delete macros that no longer exist in API
      final apiIds = macros.map((m) => m.id.toString()).toSet();
      for (final existing in existingMacros) {
        if (!apiIds.contains(existing.id.toString())) {
          await _localRepository.delete(existing.id.toString());
        }
      }
      
      // Update or create macros from API
      for (final macro in macros) {
        final existing = await _localRepository.getById(macro.id.toString());
        if (existing != null) {
          await _localRepository.update(macro);
        } else {
          await _localRepository.create(macro);
        }
      }
    } catch (e) {
      print('Error updating local cache: $e');
    }
  }
  
  Future<void> _markForSync(Macro? macro, String operation) async {
    if (macro == null) return;
    
    // Store sync operations in local storage for later processing
    // This is a simplified implementation - in production, you might want
    // a more sophisticated sync queue
    try {
      // For now, just log the operation
      print('Marked for sync: $operation macro ${macro.id}');
      // TODO: Implement proper sync queue storage
    } catch (e) {
      print('Error marking for sync: $e');
    }
  }
  
  void _startPeriodicSync() {
    _syncTimer = Timer.periodic(_syncInterval, (_) {
      if (_isOnline) {
        _performSync();
      }
    });
  }
  
  Future<void> _performSync() async {
    try {
      print('Performing sync...');
      
      // Get latest data from API
      final apiMacros = await _apiRepository.getAll();
      
      // Update local cache
      await _updateLocalCache(apiMacros);
      
      // TODO: Process sync queue for offline operations
      
      _notifyWatchers();
      print('Sync completed successfully');
    } catch (e) {
      print('Sync failed: $e');
    }
  }
  
  void _setupWatching() {
    // Combine streams from both repositories
    _localRepository.watch().listen((macros) {
      if (!_watchController.isClosed) {
        _watchController.add(macros);
      }
    });
    
    _apiRepository.watch().listen((macros) {
      if (!_watchController.isClosed) {
        _updateLocalCache(macros);
      }
    });
  }
  
  void _notifyWatchers() {
    getAll().then((macros) {
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
    _syncTimer?.cancel();
    _watchController.close();
    _localRepository.dispose();
  }
}