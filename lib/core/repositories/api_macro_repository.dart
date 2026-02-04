import 'dart:convert';
import 'package:http/http.dart' as http;
import '../interfaces/abstract_repository.dart';
import '../interfaces/macro_repository.dart';
import '../dto/macro_dto.dart';
import '../../models/macro.dart';
import '../../services/api_service.dart';

/// API-based implementation of MacroRepository
/// Handles all macro operations through REST API calls
class ApiMacroRepository extends AbstractApiRepository<Macro> implements MacroRepository {
  final ApiService _apiService;
  final MacroDtoMapper _mapper = MacroDtoMapper();
  
  ApiMacroRepository({
    required ApiService apiService,
    String baseUrl = '',
    Map<String, String> defaultHeaders = const {},
    super.cacheManager,
    super.cacheStrategy,
  }) : _apiService = apiService,
       super(
         baseUrl: baseUrl,
         defaultHeaders: defaultHeaders,
       );
  
  @override
  String get endpoint => '/macros';
  
  @override
  Macro fromJson(Map<String, dynamic> json) {
    return _mapper.toEntity(MacroDto(json));
  }
  
  @override
  Map<String, dynamic> toJson(Macro entity) {
    return _mapper.fromEntity(entity).toJson();
  }
  
  @override
  String getEntityId(Macro entity) {
    return entity.id.toString();
  }
  
  @override
  Future<void> validateEntity(Macro entity) async {
    final result = _mapper.validateEntity(entity);
    if (!result.isValid) {
      throw ArgumentError('Invalid macro: ${result.errors.join(', ')}');
    }
  }
  
  // Base repository implementations
  
  @override
  Future<Macro?> fetchById(String id) async {
    try {
      final response = await _apiService.get('$endpoint/$id');
      
      if (response['success'] == true || response['status'] == true) {
        final data = response['data'] ?? response['payload'];
        if (data != null) {
          return fromJson(data);
        }
      }
      
      return null;
    } catch (e) {
      if (e is ApiException && e.isNotFound) {
        return null;
      }
      rethrow;
    }
  }
  
  @override
  Future<List<Macro>> fetchAll() async {
    try {
      final response = await _apiService.get(endpoint);
      
      if (response['success'] == true || response['status'] == true) {
        final payload = response['data'] ?? response['payload'];
        List<dynamic> data;
        
        // Handle different response formats
        if (payload is List) {
          data = payload;
        } else if (payload is Map && payload.containsKey('data')) {
          data = payload['data'] as List<dynamic>;
        } else {
          data = [];
        }
        
        return data.map((json) => fromJson(json)).toList();
      }
      
      return [];
    } catch (e) {
      // Log error but don't throw - return empty list for graceful degradation
      print('Error fetching all macros: $e');
      return [];
    }
  }
  
  @override
  Future<List<Macro>> fetchPaginated({required int offset, required int limit}) async {
    try {
      final page = (offset ~/ limit) + 1;
      final response = await _apiService.get(
        endpoint,
        queryParams: {
          'page': page.toString(),
          'per_page': limit.toString(),
        },
      );
      
      if (response['status'] == true && response['payload'] != null) {
        final payload = response['payload'];
        final List<dynamic> data = payload['data'] is List
            ? payload['data']
            : [];
        
        return data.map((json) => fromJson(json)).toList();
      }
      
      return [];
    } catch (e) {
      print('Error fetching paginated macros: $e');
      return [];
    }
  }
  
  @override
  Future<List<Macro>> searchEntities(String query) async {
    try {
      final response = await _apiService.get(
        '$endpoint/search',
        queryParams: {'q': query},
      );
      
      if (response['status'] == true && response['payload'] != null) {
        final List<dynamic> data = response['payload'] is List
            ? response['payload']
            : [];
        
        return data.map((json) => fromJson(json)).toList();
      }
      
      return [];
    } catch (e) {
      print('Error searching macros: $e');
      return [];
    }
  }
  
  @override
  Future<Macro> createEntity(Macro entity) async {
    try {
      final response = await _apiService.post(
        endpoint,
        body: toJson(entity),
      );
      
      if (response['success'] == true || response['status'] == true) {
        final data = response['data'] ?? response['payload'];
        if (data != null) {
          return fromJson(data);
        }
      }
      
      throw Exception('Failed to create macro: ${response['message'] ?? 'Unknown error'}');
    } catch (e) {
      if (e is ApiException) {
        throw Exception('API Error: ${e.message}');
      }
      rethrow;
    }
  }
  
  @override
  Future<Macro> updateEntity(Macro entity) async {
    try {
      final response = await _apiService.put(
        '$endpoint/${entity.id}',
        body: toJson(entity),
      );
      
      if (response['success'] == true || response['status'] == true) {
        final data = response['data'] ?? response['payload'];
        if (data != null) {
          return fromJson(data);
        }
      }
      
      throw Exception('Failed to update macro: ${response['message'] ?? 'Unknown error'}');
    } catch (e) {
      if (e is ApiException) {
        throw Exception('API Error: ${e.message}');
      }
      rethrow;
    }
  }
  
  @override
  Future<void> deleteEntity(String id) async {
    try {
      final response = await _apiService.delete('$endpoint/$id');
      
      if (response['success'] != true && response['status'] != true) {
        throw Exception('Failed to delete macro: ${response['message'] ?? 'Unknown error'}');
      }
    } catch (e) {
      if (e is ApiException) {
        throw Exception('API Error: ${e.message}');
      }
      rethrow;
    }
  }
  
  // MacroRepository specific implementations
  
  @override
  Future<List<Macro>> getByCategory(String category) async {
    try {
      final response = await _apiService.get('$endpoint/category/$category');
      
      if (response['status'] == true && response['payload'] != null) {
        final List<dynamic> data = response['payload'] is List
            ? response['payload']
            : [];
        
        return data.map((json) => fromJson(json)).toList();
      }
      
      return [];
    } catch (e) {
      print('Error getting macros by category: $e');
      return [];
    }
  }
  
  @override
  Future<List<Macro>> getFavorites() async {
    try {
      final response = await _apiService.get('$endpoint/favorites');
      
      if (response['status'] == true && response['payload'] != null) {
        final List<dynamic> data = response['payload'] is List
            ? response['payload']
            : [];
        
        return data.map((json) => fromJson(json)).toList();
      }
      
      return [];
    } catch (e) {
      print('Error getting favorite macros: $e');
      return [];
    }
  }
  
  @override
  Future<List<Macro>> getMostUsed({int limit = 10}) async {
    try {
      final response = await _apiService.get(
        '$endpoint/most-used',
        queryParams: {'limit': limit.toString()},
      );
      
      if (response['status'] == true && response['payload'] != null) {
        final List<dynamic> data = response['payload'] is List
            ? response['payload']
            : [];
        
        return data.map((json) => fromJson(json)).toList();
      }
      
      return [];
    } catch (e) {
      print('Error getting most used macros: $e');
      return [];
    }
  }
  
  @override
  Future<void> toggleFavorite(String id) async {
    try {
      final response = await _apiService.patch('$endpoint/$id/toggle-favorite');
      
      if (response['status'] != true) {
        throw Exception('Failed to toggle favorite: ${response['message'] ?? 'Unknown error'}');
      }
    } catch (e) {
      if (e is ApiException) {
        throw Exception('API Error: ${e.message}');
      }
      rethrow;
    }
  }
  
  @override
  Future<void> incrementUsage(String id) async {
    try {
      final response = await _apiService.patch('$endpoint/$id/increment-usage');
      
      if (response['status'] != true) {
        // Don't throw for usage increment failures - it's not critical
        print('Warning: Failed to increment usage for macro $id');
      }
    } catch (e) {
      // Log but don't throw - usage tracking is not critical
      print('Warning: Error incrementing usage for macro $id: $e');
    }
  }
  
  @override
  Future<List<String>> getCategories() async {
    try {
      final response = await _apiService.get('$endpoint/categories');
      
      if (response['status'] == true && response['payload'] != null) {
        final List<dynamic> data = response['payload'] is List
            ? response['payload']
            : [];
        
        return data.map((item) => item.toString()).toList();
      }
      
      return [];
    } catch (e) {
      print('Error getting categories: $e');
      return [];
    }
  }
  
  @override
  Future<String?> findExpansion(String text) async {
    try {
      final response = await _apiService.get(
        '$endpoint/find-expansion',
        queryParams: {'text': text},
      );
      
      if (response['status'] == true && response['payload'] != null) {
        final payload = response['payload'];
        if (payload['expansion'] != null) {
          // Increment usage if expansion found
          final macroId = payload['macro_id'];
          if (macroId != null) {
            await incrementUsage(macroId.toString());
          }
          return payload['expansion'];
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
      final response = await _apiService.get(
        '$endpoint/search-trigger',
        queryParams: {'trigger': trigger},
      );
      
      if (response['status'] == true && response['payload'] != null) {
        final List<dynamic> data = response['payload'] is List
            ? response['payload']
            : [];
        
        return data.map((json) => fromJson(json)).toList();
      }
      
      return [];
    } catch (e) {
      print('Error searching by trigger: $e');
      return [];
    }
  }
  
  @override
  Future<String> getMacrosAsJson() async {
    try {
      final macros = await getAll();
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
    // For API repository, sync is implicit - all operations are already synced
    // This method is a no-op but could be used for cache invalidation
    if (cacheManager != null) {
      await cacheManager!.clear();
    }
  }
  
  @override
  Stream<List<Macro>> watch() {
    // For API repository, implement polling-based watching
    return Stream.periodic(
      const Duration(seconds: 30), // Poll every 30 seconds
      (_) => getAll(),
    ).asyncMap((future) => future);
  }
}