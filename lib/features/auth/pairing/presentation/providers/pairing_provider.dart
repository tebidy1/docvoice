import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../../core/config/api_config.dart';
import '../../data/datasources/pairing_remote_datasource.dart';
import '../../data/repositories/pairing_repository_impl.dart';
import '../../domain/entities/pairing_session.dart';
import '../../domain/repositories/pairing_repository.dart';

// Dio Provider
final dioProvider = Provider<Dio>((ref) {
  final baseUrl = ApiConfig.baseUrl;
  final dio = Dio(BaseOptions(
    baseUrl: baseUrl.endsWith('/') ? baseUrl : '$baseUrl/',
    headers: {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    },
  ));

  // Add Auth Interceptor
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) async {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
      return handler.next(options);
    },
  ));

  return dio;
});

// DataSource Provider
final pairingDataSourceProvider = Provider<PairingRemoteDataSource>((ref) {
  return PairingRemoteDataSource(ref.read(dioProvider));
});

// Repository Provider
final pairingRepositoryProvider = Provider<PairingRepository>((ref) {
  return PairingRepositoryImpl(ref.read(pairingDataSourceProvider));
});

// State Notifier for Pairing
class PairingNotifier extends StateNotifier<AsyncValue<PairingSession?>> {
  final PairingRepository _repository;

  PairingNotifier(this._repository) : super(const AsyncValue.data(null));

  Future<void> initiate() async {
    state = const AsyncValue.loading();
    try {
      final session = await _repository.initiatePairing();
      state = AsyncValue.data(session);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<Map<String, dynamic>> checkStatus(String id) async {
    return await _repository.checkStatus(id);
  }

  Future<bool> authorize(String id, {String? deviceName}) async {
    return await _repository.authorizePairing(id, deviceName: deviceName);
  }
}

final pairingProvider =
    StateNotifierProvider<PairingNotifier, AsyncValue<PairingSession?>>((ref) {
  return PairingNotifier(ref.read(pairingRepositoryProvider));
});
