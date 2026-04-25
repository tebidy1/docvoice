import 'package:flutter/foundation.dart';
import 'package:soutnote/core/network/api_client.dart';

/// Base class for all API services providing common CRUD operations
///
/// This abstract class provides a foundation for creating specialized API services
/// with standardized methods for Create, Read, Update, and Delete operations.
///
/// Example usage:
/// ```dart
/// class InboxNoteApiClient extends BaseApiClient {
///   @override
///   String get baseEndpoint => '/inbox-notes';
/// }
/// ```
abstract class BaseApiClient {
  final ApiClient _ApiClient = ApiClient();

  /// Base endpoint for the service (e.g., '/inbox-notes', '/macros')
  /// Must be implemented by subclasses
  String get baseEndpoint;

  // ============================================
  // CRUD Operations
  // ============================================

  /// Fetch all items from the endpoint
  ///
  /// [queryParams] - Optional query parameters for filtering
  /// [fromJson] - Function to convert JSON to model object
  ///
  /// Returns a list of items of type T
  Future<List<T>> fetchAll<T>({
    Map<String, String>? queryParams,
    required T Function(dynamic) fromJson,
  }) async {
    try {
      final response = await _ApiClient.get(
        baseEndpoint,
        queryParams: queryParams,
      );

      // Handle different response formats
      final dynamic data = response['data'] ?? response['payload'] ?? [];

      if (data is List) {
        return data.map((item) => fromJson(item)).toList();
      }

      // Fallback if data is not a list
      return [];
    } catch (e) {
      debugPrint('❌ Error fetching all from $baseEndpoint: $e');
      rethrow;
    }
  }

  /// Fetch a single item by ID
  Future<T> fetchById<T>({
    required String id,
    required T Function(dynamic) fromJson,
  }) async {
    try {
      final response = await _ApiClient.get('$baseEndpoint/$id');
      final data = response['data'] ?? response['payload'];
      return fromJson(data);
    } catch (e) {
      debugPrint('❌ Error fetching $id from $baseEndpoint: $e');
      rethrow;
    }
  }

  /// Create a new item
  Future<T> create<T>({
    required Map<String, dynamic> data,
    required T Function(dynamic) fromJson,
  }) async {
    try {
      final response = await _ApiClient.post(baseEndpoint, body: data);
      final responseData = response['data'] ?? response['payload'];
      return fromJson(responseData);
    } catch (e) {
      debugPrint('❌ Error creating in $baseEndpoint: $e');
      rethrow;
    }
  }

  /// Update an existing item
  Future<T> update<T>({
    required String id,
    required Map<String, dynamic> data,
    required T Function(dynamic) fromJson,
  }) async {
    try {
      final response = await _ApiClient.put('$baseEndpoint/$id', body: data);
      final responseData = response['data'] ?? response['payload'];
      return fromJson(responseData);
    } catch (e) {
      debugPrint('❌ Error updating $id in $baseEndpoint: $e');
      rethrow;
    }
  }

  /// Delete an item
  Future<bool> delete({required String id}) async {
    try {
      await _ApiClient.delete('$baseEndpoint/$id');
      debugPrint('✅ Deleted $id from $baseEndpoint');
      return true;
    } catch (e) {
      debugPrint('❌ Error deleting $id from $baseEndpoint: $e');
      return false;
    }
  }

  /// Perform a PATCH operation (partial update)
  Future<T> patch<T>({
    required String endpoint,
    Map<String, dynamic>? data,
    required T Function(dynamic) fromJson,
  }) async {
    try {
      final response = await _ApiClient.patch(endpoint, body: data);
      final responseData = response['data'] ?? response['payload'];
      return fromJson(responseData);
    } catch (e) {
      debugPrint('❌ Error patching $endpoint: $e');
      rethrow;
    }
  }

  /// Perform a custom GET request to a specific endpoint
  Future<T> customGet<T>({
    required String endpoint,
    Map<String, String>? queryParams,
    required T Function(dynamic) fromJson,
  }) async {
    try {
      final response = await _ApiClient.get(endpoint, queryParams: queryParams);
      final data = response['data'] ?? response['payload'];
      return fromJson(data);
    } catch (e) {
      debugPrint('❌ Error in custom GET $endpoint: $e');
      rethrow;
    }
  }

  /// Perform a custom POST request to a specific endpoint
  Future<T> customPost<T>({
    required String endpoint,
    Map<String, dynamic>? data,
    required T Function(dynamic) fromJson,
  }) async {
    try {
      final response = await _ApiClient.post(endpoint, body: data);
      final responseData = response['data'] ?? response['payload'];
      return fromJson(responseData);
    } catch (e) {
      debugPrint('❌ Error in custom POST $endpoint: $e');
      rethrow;
    }
  }
}
