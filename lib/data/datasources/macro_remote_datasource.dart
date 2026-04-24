import '../../core/network/api_client.dart';

abstract class MacroRemoteDataSource {
  Future<List<Map<String, dynamic>>> getMacros({String? category});
  Future<Map<String, dynamic>> createMacro(Map<String, dynamic> data);
  Future<Map<String, dynamic>> updateMacro(
      dynamic id, Map<String, dynamic> data);
  Future<void> deleteMacro(dynamic id);
}

class MacroRemoteDataSourceImpl implements MacroRemoteDataSource {
  final ApiClient _apiClient;

  MacroRemoteDataSourceImpl(this._apiClient);

  @override
  Future<List<Map<String, dynamic>>> getMacros({String? category}) async {
    final queryParams = <String, String>{};
    if (category != null) queryParams['category'] = category;
    final response = await _apiClient.get('/macros', queryParams: queryParams);
    final payload = response['payload'];
    if (payload is List) return payload.cast<Map<String, dynamic>>();
    return [];
  }

  @override
  Future<Map<String, dynamic>> createMacro(Map<String, dynamic> data) async {
    return await _apiClient.post('/macros', body: data);
  }

  @override
  Future<Map<String, dynamic>> updateMacro(
      dynamic id, Map<String, dynamic> data) async {
    return await _apiClient.put('/macros/$id', body: data);
  }

  @override
  Future<void> deleteMacro(dynamic id) async {
    await _apiClient.delete('/macros/$id');
  }
}
