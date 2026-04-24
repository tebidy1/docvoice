import 'package:soutnote/core/network/api_client.dart';

abstract class InboxRemoteDataSource {
  Future<List<Map<String, dynamic>>> getInboxNotes({String? status});
  Future<Map<String, dynamic>> getInboxNote(String id);
  Future<Map<String, dynamic>> createInboxNote(Map<String, dynamic> data);
  Future<Map<String, dynamic>> updateInboxNote(
      String id, Map<String, dynamic> data);
  Future<void> deleteInboxNote(String id);
  Future<Map<String, dynamic>> applyMacro(String noteId, String macroId);
}

class InboxRemoteDataSourceImpl implements InboxRemoteDataSource {
  final ApiClient _apiClient;

  InboxRemoteDataSourceImpl(this._apiClient);

  @override
  Future<List<Map<String, dynamic>>> getInboxNotes({String? status}) async {
    final queryParams = <String, String>{};
    if (status != null) queryParams['status'] = status;
    final response =
        await _apiClient.get('/inbox-notes', queryParams: queryParams);
    final payload = response['payload'] ?? response['data'];
    if (payload is List) return payload.cast<Map<String, dynamic>>();
    return [];
  }

  @override
  Future<Map<String, dynamic>> getInboxNote(String id) async {
    return await _apiClient.get('/inbox-notes/$id');
  }

  @override
  Future<Map<String, dynamic>> createInboxNote(Map<String, dynamic> data) async {
    return await _apiClient.post('/inbox-notes', body: data);
  }

  @override
  Future<Map<String, dynamic>> updateInboxNote(
      String id, Map<String, dynamic> data) async {
    return await _apiClient.put('/inbox-notes/$id', body: data);
  }

  @override
  Future<void> deleteInboxNote(String id) async {
    await _apiClient.delete('/inbox-notes/$id');
  }

  @override
  Future<Map<String, dynamic>> applyMacro(String noteId, String macroId) async {
    return await _apiClient.post('/inbox-notes/$noteId/apply-macro', body: {
      'macro_id': macroId,
    });
  }
}
