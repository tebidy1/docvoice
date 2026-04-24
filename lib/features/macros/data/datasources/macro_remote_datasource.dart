import 'package:soutnote/core/network/api_client.dart';

class MacroRemoteDataSource {
  final ApiClient _apiClient;

  MacroRemoteDataSource({required ApiClient apiClient}) : _apiClient = apiClient;

  Future<List<Map<String, dynamic>>> getAll() async {
    final response = await _apiClient.get('/macros');
    final data = response['data'] ?? response['payload'] ?? response;
    if (data is List) return data.cast<Map<String, dynamic>>();
    return [];
  }

  Future<Map<String, dynamic>> getById(String id) async {
    return await _apiClient.get('/macros/$id');
  }

  Future<Map<String, dynamic>> create(Map<String, dynamic> data) async {
    return await _apiClient.post('/macros', body: data);
  }

  Future<Map<String, dynamic>> update(String id, Map<String, dynamic> data) async {
    return await _apiClient.put('/macros/$id', body: data);
  }

  Future<void> delete(String id) async {
    await _apiClient.delete('/macros/$id');
  }

  Future<List<Map<String, dynamic>>> getByCategory(String category) async {
    final response = await _apiClient.get('/macros', queryParams: {'category': category});
    final data = response['data'] ?? response['payload'] ?? response;
    if (data is List) return data.cast<Map<String, dynamic>>();
    return [];
  }
}
