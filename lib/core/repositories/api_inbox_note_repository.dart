import 'dart:async';
import '../interfaces/abstract_repository.dart';
import '../interfaces/inbox_note_repository.dart';
import '../dto/inbox_note_dto.dart';
import '../../models/inbox_note.dart';
import '../../services/api_service.dart';

/// API-based implementation of InboxNoteRepository
/// Handles all inbox note operations through REST API calls
class ApiInboxNoteRepository extends AbstractApiRepository<InboxNote> implements InboxNoteRepository {
  final ApiService _apiService;
  final InboxNoteDtoMapper _mapper = InboxNoteDtoMapper();
  
  ApiInboxNoteRepository({
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
  String get endpoint => '/inbox-notes';
  
  @override
  InboxNote fromJson(Map<String, dynamic> json) {
    return _mapper.toEntity(InboxNoteDto(json));
  }
  
  @override
  Map<String, dynamic> toJson(InboxNote entity) {
    return _mapper.fromEntity(entity).toJson();
  }
  
  @override
  String getEntityId(InboxNote entity) {
    return entity.id.toString();
  }
  
  @override
  Future<void> validateEntity(InboxNote entity) async {
    final result = _mapper.validateEntity(entity);
    if (!result.isValid) {
      throw ArgumentError('Invalid inbox note: ${result.errors.join(', ')}');
    }
  }
  
  // Base repository implementations
  
  @override
  Future<InboxNote?> fetchById(String id) async {
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
  Future<List<InboxNote>> fetchAll() async {
    try {
      final response = await _apiService.get(endpoint);
      
      if (response['success'] == true || response['status'] == true) {
        final payload = response['data'] ?? response['payload'];
        List<dynamic> data;
        
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
      print('Error fetching all inbox notes: $e');
      return [];
    }
  }
  
  @override
  Future<List<InboxNote>> fetchPaginated({required int offset, required int limit}) async {
    try {
      final page = (offset ~/ limit) + 1;
      final response = await _apiService.get(
        endpoint,
        queryParams: {
          'page': page.toString(),
          'per_page': limit.toString(),
        },
      );
      
      if (response['success'] == true || response['status'] == true) {
        final payload = response['data'] ?? response['payload'];
        List<dynamic> data;
        
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
      print('Error fetching paginated inbox notes: $e');
      return [];
    }
  }
  
  @override
  Future<List<InboxNote>> searchEntities(String query) async {
    try {
      final response = await _apiService.get(
        '$endpoint/search',
        queryParams: {'q': query},
      );
      
      if (response['success'] == true || response['status'] == true) {
        final data = response['data'] ?? response['payload'];
        if (data is List) {
          return data.map((json) => fromJson(json)).toList();
        }
      }
      
      return [];
    } catch (e) {
      print('Error searching inbox notes: $e');
      return [];
    }
  }
  
  @override
  Future<InboxNote> createEntity(InboxNote entity) async {
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
      
      throw Exception('Failed to create inbox note: ${response['message'] ?? 'Unknown error'}');
    } catch (e) {
      if (e is ApiException) {
        throw Exception('API Error: ${e.message}');
      }
      rethrow;
    }
  }
  
  @override
  Future<InboxNote> updateEntity(InboxNote entity) async {
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
      
      throw Exception('Failed to update inbox note: ${response['message'] ?? 'Unknown error'}');
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
        throw Exception('Failed to delete inbox note: ${response['message'] ?? 'Unknown error'}');
      }
    } catch (e) {
      if (e is ApiException) {
        throw Exception('API Error: ${e.message}');
      }
      rethrow;
    }
  }
  
  // InboxNoteRepository specific implementations
  
  @override
  Future<List<InboxNote>> getPending() async {
    try {
      final response = await _apiService.get('$endpoint/pending');
      
      if (response['success'] == true || response['status'] == true) {
        final data = response['data'] ?? response['payload'];
        if (data is List) {
          return data.map((json) => fromJson(json)).toList();
        }
      }
      
      return [];
    } catch (e) {
      print('Error getting pending inbox notes: $e');
      return [];
    }
  }
  
  @override
  Future<List<InboxNote>> getArchived() async {
    try {
      final response = await _apiService.get('$endpoint/archived');
      
      if (response['success'] == true || response['status'] == true) {
        final data = response['data'] ?? response['payload'];
        if (data is List) {
          return data.map((json) => fromJson(json)).toList();
        }
      }
      
      return [];
    } catch (e) {
      print('Error getting archived inbox notes: $e');
      return [];
    }
  }
  
  @override
  Future<List<InboxNote>> getByStatus(NoteStatus status) async {
    try {
      final statusString = status.toString().split('.').last;
      final response = await _apiService.get(
        endpoint,
        queryParams: {'status': statusString},
      );
      
      if (response['success'] == true || response['status'] == true) {
        final data = response['data'] ?? response['payload'];
        if (data is List) {
          return data.map((json) => fromJson(json)).toList();
        }
      }
      
      return [];
    } catch (e) {
      print('Error getting inbox notes by status: $e');
      return [];
    }
  }
  
  @override
  Future<void> updateStatus(String id, NoteStatus status) async {
    try {
      final statusString = status.toString().split('.').last;
      final response = await _apiService.patch('$endpoint/$id/status', body: {
        'status': statusString,
      });
      
      if (response['success'] != true && response['status'] != true) {
        throw Exception('Failed to update status: ${response['message'] ?? 'Unknown error'}');
      }
    } catch (e) {
      if (e is ApiException) {
        throw Exception('API Error: ${e.message}');
      }
      rethrow;
    }
  }
  
  @override
  Future<void> archive(String id) async {
    try {
      final response = await _apiService.patch('$endpoint/$id/archive');
      
      if (response['success'] != true && response['status'] != true) {
        throw Exception('Failed to archive note: ${response['message'] ?? 'Unknown error'}');
      }
    } catch (e) {
      if (e is ApiException) {
        throw Exception('API Error: ${e.message}');
      }
      rethrow;
    }
  }
  
  @override
  Future<List<InboxNote>> searchByContent(String query) async {
    return await searchEntities(query);
  }

  @override
  Future<List<InboxNote>> getRecent({int limit = 20}) async {
    try {
      final response = await _apiService.get(
        endpoint,
        queryParams: {'limit': limit.toString()},
      );
      
      if (response['success'] == true || response['status'] == true) {
        final data = response['data'] ?? response['payload'];
        if (data is List) {
          return data.map((json) => fromJson(json)).toList();
        }
      }
      
      return [];
    } catch (e) {
      print('Error getting recent inbox notes: $e');
      return [];
    }
  }

  @override
  Future<List<InboxNote>> getByDateRange(DateTime start, DateTime end) async {
    try {
      final response = await _apiService.get(
        endpoint,
        queryParams: {
          'start_date': start.toIso8601String(),
          'end_date': end.toIso8601String(),
        },
      );
      
      if (response['success'] == true || response['status'] == true) {
        final data = response['data'] ?? response['payload'];
        if (data is List) {
          return data.map((json) => fromJson(json)).toList();
        }
      }
      
      return [];
    } catch (e) {
      print('Error getting inbox notes by date range: $e');
      return [];
    }
  }

  @override
  Future<List<InboxNote>> getNotesWithAudio() async {
    try {
      final response = await _apiService.get('$endpoint/with-audio');
      
      if (response['success'] == true || response['status'] == true) {
        final data = response['data'] ?? response['payload'];
        if (data is List) {
          return data.map((json) => fromJson(json)).toList();
        }
      }
      
      return [];
    } catch (e) {
      print('Error getting inbox notes with audio: $e');
      return [];
    }
  }

  @override
  Future<void> applyMacro(String noteId, String macroId) async {
    try {
      final response = await _apiService.post('$endpoint/$noteId/apply-macro', body: {
        'macro_id': macroId,
      });
      
      if (response['success'] != true && response['status'] != true) {
        throw Exception('Failed to apply macro: ${response['message'] ?? 'Unknown error'}');
      }
    } catch (e) {
      if (e is ApiException) {
        throw Exception('API Error: ${e.message}');
      }
      rethrow;
    }
  }

  @override
  Future<void> sync() async {
    // For API repository, sync is usually implicitly handled by REST calls
    // But we can implement a refresh of all cached data if needed
    await getAll();
  }
  
  @override
  Stream<List<InboxNote>> watch() {
    // For API repository, implement polling-based watching
    return Stream.periodic(
      const Duration(seconds: 30), // Poll every 30 seconds
      (_) => getAll(),
    ).asyncMap((future) => future);
  }
}