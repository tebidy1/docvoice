import '../models/macro.dart';
import 'api_service.dart';

class MacroService {
  static final MacroService _instance = MacroService._internal();
  factory MacroService() => _instance;
  MacroService._internal();

  final ApiService _apiService = ApiService();
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) {
      return;
    }
    await _apiService.init();
    _isInitialized = true;
  }

  Future<void> addMacro(
    String trigger,
    String content, {
    bool isAiMacro = false,
    String? aiInstruction,
    String category = 'General',
  }) async {
    await init();
    try {
      final response = await _apiService.post('/macros', body: {
        'trigger': trigger,
        'content': content,
        'is_ai_macro': isAiMacro,
        if (aiInstruction != null) 'ai_instruction': aiInstruction,
        'category': category,
      });

      if (response['status'] != true) {
        throw Exception(response['message'] ?? 'Failed to add macro');
      }
    } catch (e) {
      print('Error adding macro: $e');
      rethrow;
    }
  }

  Future<void> deleteMacro(int id) async {
    await init();
    try {
      final response = await _apiService.delete('/macros/$id');

      if (response['status'] != true) {
        throw Exception(response['message'] ?? 'Failed to delete macro');
      }
    } catch (e) {
      print('Error deleting macro: $e');
      rethrow;
    }
  }

  Future<void> updateMacro(
    int id,
    String trigger,
    String content, {
    bool? isAiMacro,
    String? aiInstruction,
    String? category,
  }) async {
    await init();
    try {
      final body = <String, dynamic>{
        'trigger': trigger,
        'content': content,
      };

      if (isAiMacro != null) body['is_ai_macro'] = isAiMacro;
      if (aiInstruction != null) body['ai_instruction'] = aiInstruction;
      if (category != null) body['category'] = category;

      final response = await _apiService.put('/macros/$id', body: body);

      if (response['status'] != true) {
        throw Exception(response['message'] ?? 'Failed to update macro');
      }
    } catch (e) {
      print('Error updating macro: $e');
      rethrow;
    }
  }

  Future<void> toggleFavorite(int id) async {
    await init();
    try {
      final response = await _apiService.patch('/macros/$id/toggle-favorite');

      if (response['status'] != true) {
        throw Exception(response['message'] ?? 'Failed to toggle favorite');
      }
    } catch (e) {
      print('Error toggling favorite: $e');
      rethrow;
    }
  }

  Future<List<Macro>> getAllMacros() async {
    try {
      final response = await _apiService.get('/macros');

      if (response['status'] == true && response['payload'] != null) {
        final payload = response['payload'];
        final List<dynamic> data = payload['data'] is List
            ? payload['data']
            : (payload is List ? payload : []);

        return data.map((json) => _mapToMacro(json)).toList();
      }

      return [];
    } catch (e) {
      print('Error getting all macros: $e');
      return [];
    }
  }

  Future<List<Macro>> getMacrosByCategory(String category) async {
    await init();
    try {
      final response = await _apiService.get('/macros/category/$category');

      if (response['status'] == true && response['payload'] != null) {
        final List<dynamic> data = response['payload'] is List
            ? response['payload']
            : [];

        return data.map((json) => _mapToMacro(json)).toList();
      }

      return [];
    } catch (e) {
      print('Error getting macros by category: $e');
      return [];
    }
  }

  Future<List<Macro>> getMostUsed({int limit = 10}) async {
    await init();
    try {
      final response = await _apiService.get(
        '/macros/most-used',
        queryParams: {'limit': limit.toString()},
      );

      if (response['status'] == true && response['payload'] != null) {
        final List<dynamic> data = response['payload'] is List
            ? response['payload']
            : [];

        return data.map((json) => _mapToMacro(json)).toList();
      }

      return [];
    } catch (e) {
      print('Error getting most used macros: $e');
      return [];
    }
  }

  Future<List<String>> getCategories() async {
    await init();
    try {
      final response = await _apiService.get('/macros/categories');

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

  Future<List<Macro>> getFavorites() async {
    await init();
    try {
      final response = await _apiService.get('/macros/favorites');

      if (response['status'] == true && response['payload'] != null) {
        final List<dynamic> data = response['payload'] is List
            ? response['payload']
            : [];

        return data.map((json) => _mapToMacro(json)).toList();
      }

      return [];
    } catch (e) {
      print('Error getting favorites: $e');
      return [];
    }
  }

  Future<String?> findExpansion(String text) async {
    try {
      final macros = await getAllMacros();

      // Sort by length descending to match longest phrases first
      macros.sort((a, b) => b.trigger.length.compareTo(a.trigger.length));

      final normalizedText = text.toLowerCase();

      for (var macro in macros) {
        if (normalizedText.contains(macro.trigger.toLowerCase())) {
          // Increment usage count
          await _incrementUsage(macro.id);
          return macro.content;
        }
      }

      return null;
    } catch (e) {
      print('Error finding expansion: $e');
      return null;
    }
  }

  Future<void> _incrementUsage(int id) async {
    try {
      await _apiService.patch('/macros/$id/increment-usage');
    } catch (e) {
      print('Error incrementing usage: $e');
      // Don't throw - this is a non-critical operation
    }
  }

  Macro _mapToMacro(Map<String, dynamic> json) {
    final macro = Macro();
    macro.id = json['id'] ?? 0;
    macro.trigger = json['trigger'] ?? '';
    macro.content = json['content'] ?? '';
    macro.isFavorite = json['is_favorite'] ?? false;
    macro.usageCount = json['usage_count'] ?? 0;
    macro.lastUsed = json['last_used'] != null
        ? DateTime.parse(json['last_used'])
        : null;
    macro.isAiMacro = json['is_ai_macro'] ?? false;
    macro.aiInstruction = json['ai_instruction'];
    macro.category = json['category'] ?? 'General';
    macro.createdAt = json['created_at'] != null
        ? DateTime.parse(json['created_at'])
        : DateTime.now();
    return macro;
  }
}
