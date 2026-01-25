import 'package:flutter/foundation.dart';
import '../models/macro.dart';
import 'base_api_service.dart';

/// API Service for Macros
///
/// Provides methods to interact with the macros API endpoints.
/// Supports CRUD operations, favorites, categories, and usage tracking.
///
/// Example usage:
/// ```dart
/// final service = MacroApiService();
/// final macros = await service.fetchMacros();
/// await service.toggleFavorite(macroId);
/// ```
class MacroApiService extends BaseApiService {
  @override
  String get baseEndpoint => '/macros';

  // ============================================
  // Fetch Operations
  // ============================================

  /// Fetch all macros
  Future<List<Macro>> fetchMacros() async {
    return await fetchAll<Macro>(
      fromJson: (json) => Macro.fromJson(json),
    );
  }

  /// Fetch macros by category
  Future<List<Macro>> fetchByCategory(String category) async {
    return await customGet<List<Macro>>(
      endpoint: '$baseEndpoint/category/$category',
      fromJson: (json) {
        final List<dynamic> data = json is List ? json : (json['data'] ?? []);
        return data.map((item) => Macro.fromJson(item)).toList();
      },
    );
  }

  /// Fetch favorite macros
  Future<List<Macro>> fetchFavorites() async {
    return await customGet<List<Macro>>(
      endpoint: '$baseEndpoint/favorites',
      fromJson: (json) {
        final List<dynamic> data = json is List ? json : (json['data'] ?? []);
        return data.map((item) => Macro.fromJson(item)).toList();
      },
    );
  }

  /// Fetch most used macros
  Future<List<Macro>> fetchMostUsed() async {
    return await customGet<List<Macro>>(
      endpoint: '$baseEndpoint/most-used',
      fromJson: (json) {
        final List<dynamic> data = json is List ? json : (json['data'] ?? []);
        return data.map((item) => Macro.fromJson(item)).toList();
      },
    );
  }

  /// Fetch available categories
  Future<List<String>> fetchCategories() async {
    return await customGet<List<String>>(
      endpoint: '$baseEndpoint/categories',
      fromJson: (json) {
        final List<dynamic> data = json is List ? json : (json['data'] ?? []);
        return data.map((item) => item.toString()).toList();
      },
    );
  }

  /// Fetch a single macro by ID
  Future<Macro> fetchMacroById(String id) async {
    return await fetchById<Macro>(
      id: id,
      fromJson: (json) => Macro.fromJson(json),
    );
  }

  // ============================================
  // Create & Update Operations
  // ============================================

  /// Create a new macro
  Future<Macro> createMacro(Macro macro) async {
    return await create<Macro>(
      data: macro.toJson(),
      fromJson: (json) => Macro.fromJson(json),
    );
  }

  /// Update an existing macro
  Future<Macro> updateMacro(String id, Macro macro) async {
    return await update<Macro>(
      id: id,
      data: macro.toJson(),
      fromJson: (json) => Macro.fromJson(json),
    );
  }

  // ============================================
  // Favorite Operations
  // ============================================

  /// Toggle favorite status of a macro
  Future<Macro> toggleFavorite(String id) async {
    return await patch<Macro>(
      endpoint: '$baseEndpoint/$id/toggle-favorite',
      fromJson: (json) => Macro.fromJson(json),
    );
  }

  // ============================================
  // Usage Tracking
  // ============================================

  /// Increment usage count for a macro
  Future<Macro> incrementUsage(String id) async {
    return await patch<Macro>(
      endpoint: '$baseEndpoint/$id/increment-usage',
      fromJson: (json) => Macro.fromJson(json),
    );
  }

  // ============================================
  // Delete Operations
  // ============================================

  /// Delete a macro
  Future<bool> deleteMacro(String id) async {
    return await delete(id: id);
  }

  // ============================================
  // Batch Operations
  // ============================================

  /// Delete multiple macros at once
  Future<int> deleteMultiple(List<String> ids) async {
    int successCount = 0;

    for (final id in ids) {
      try {
        final success = await deleteMacro(id);
        if (success) successCount++;
      } catch (e) {
        debugPrint('Failed to delete macro $id: $e');
      }
    }

    return successCount;
  }

  /// Toggle favorite for multiple macros
  Future<List<Macro>> toggleFavoriteMultiple(List<String> ids) async {
    final results = <Macro>[];

    for (final id in ids) {
      try {
        final macro = await toggleFavorite(id);
        results.add(macro);
      } catch (e) {
        debugPrint('Failed to toggle favorite for macro $id: $e');
      }
    }

    return results;
  }

  // ============================================
  // Search & Filter
  // ============================================

  /// Search macros by title or content
  /// Note: This is a client-side filter. For server-side search,
  /// the backend would need to implement a search endpoint.
  Future<List<Macro>> searchMacros(String query) async {
    final allMacros = await fetchMacros();

    if (query.isEmpty) return allMacros;

    final lowerQuery = query.toLowerCase();
    return allMacros.where((macro) {
      return macro.trigger.toLowerCase().contains(lowerQuery) ||
          macro.content.toLowerCase().contains(lowerQuery) ||
          (macro.category.toLowerCase().contains(lowerQuery));
    }).toList();
  }
}
