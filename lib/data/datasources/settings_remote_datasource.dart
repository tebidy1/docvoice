import 'package:soutnote/core/network/api_client.dart';

abstract class SettingsRemoteDataSource {
  Future<Map<String, dynamic>?> getCompanySettings();
  Future<bool> updateCompanySettings(Map<String, dynamic> settings);
}

class SettingsRemoteDataSourceImpl implements SettingsRemoteDataSource {
  final ApiClient _apiClient;

  SettingsRemoteDataSourceImpl(this._apiClient);

  @override
  Future<Map<String, dynamic>?> getCompanySettings() async {
    final response = await _apiClient.get('/company/settings');
    if (response['status'] == true || response['success'] == true) {
      final payload = response['payload'];
      if (payload != null && payload is Map<String, dynamic>) {
        if (payload.containsKey('settings')) {
          return payload['settings'] as Map<String, dynamic>;
        }
        return payload;
      }
      if (response.containsKey('settings')) {
        return response['settings'] as Map<String, dynamic>;
      }
    }
    return null;
  }

  @override
  Future<bool> updateCompanySettings(Map<String, dynamic> settings) async {
    final response = await _apiClient.put('/company/settings', body: settings);
    return response['success'] == true;
  }
}
