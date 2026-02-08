import 'package:dio/dio.dart';

class PairingRemoteDataSource {
  final Dio _dio;

  PairingRemoteDataSource(this._dio);

  Future<Map<String, dynamic>> initiate() async {
    final response = await _dio.get('/pairing/initiate');
    return response.data;
  }

  Future<Map<String, dynamic>> checkStatus(String pairingId) async {
    final response = await _dio.get('/pairing/check/$pairingId');
    return response.data;
  }

  Future<Map<String, dynamic>> authorize(
      String pairingId, String deviceName) async {
    final response = await _dio.post('/pairing/authorize', data: {
      'pairing_id': pairingId,
      'device_name': deviceName,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> claim(
      String pairingId, String deviceName) async {
    final response = await _dio.post('/pairing/claim', data: {
      'pairing_id': pairingId,
      'device_name': deviceName,
    });
    return response.data;
  }
}
