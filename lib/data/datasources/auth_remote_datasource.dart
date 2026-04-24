import '../../core/network/api_client.dart';

abstract class AuthRemoteDataSource {
  Future<Map<String, dynamic>> login(String email, String password,
      {String? deviceName});
  Future<Map<String, dynamic>> register(Map<String, dynamic> data);
  Future<void> logout();
  Future<Map<String, dynamic>> getProfile();
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final ApiClient _apiClient;

  AuthRemoteDataSourceImpl(this._apiClient);

  @override
  Future<Map<String, dynamic>> login(String email, String password,
      {String? deviceName}) async {
    return await _apiClient.post('/auth/login', body: {
      'email': email,
      'password': password,
      if (deviceName != null) 'device_name': deviceName,
    });
  }

  @override
  Future<Map<String, dynamic>> register(Map<String, dynamic> data) async {
    return await _apiClient.post('/auth/register', body: data);
  }

  @override
  Future<void> logout() async {
    await _apiClient.post('/auth/logout');
  }

  @override
  Future<Map<String, dynamic>> getProfile() async {
    return await _apiClient.get('/auth/profile');
  }
}
