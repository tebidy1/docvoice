import 'package:soutnote/core/network/api_client.dart';

class InboxRemoteDataSource {
  final ApiClient _apiClient;

  InboxRemoteDataSource({required ApiClient apiClient}) : _apiClient = apiClient;

  Future<List<Map<String, dynamic>>> getAll() async {
    final response = await _apiClient.get('/inbox-notes');
    final data = response['data'] ?? response['payload'] ?? response;
    if (data is List) return data.cast<Map<String, dynamic>>();
    return [];
  }

  Future<Map<String, dynamic>> getById(String id) async {
    return await _apiClient.get('/inbox-notes/$id');
  }

  Future<Map<String, dynamic>> create(Map<String, dynamic> data) async {
    return await _apiClient.post('/inbox-notes', body: data);
  }

  Future<Map<String, dynamic>> update(String id, Map<String, dynamic> data) async {
    return await _apiClient.put('/inbox-notes/$id', body: data);
  }

  Future<void> delete(String id) async {
    await _apiClient.delete('/inbox-notes/$id');
  }
}
