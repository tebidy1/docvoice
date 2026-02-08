import '../../domain/entities/pairing_session.dart';
import '../../domain/repositories/pairing_repository.dart';
import '../datasources/pairing_remote_datasource.dart';

class PairingRepositoryImpl implements PairingRepository {
  final PairingRemoteDataSource _remoteDataSource;

  PairingRepositoryImpl(this._remoteDataSource);

  @override
  Future<Map<String, dynamic>> checkStatus(String pairingId) async {
    try {
      final data = await _remoteDataSource.checkStatus(pairingId);
      return data;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  @override
  Future<PairingSession> initiatePairing() async {
    try {
      final data = await _remoteDataSource.initiate();
      if (data['success'] == true) {
        return PairingSession(
          id: data['pairing_id'],
          shortCode: data['short_code'],
          expiresIn: data['expires_in'],
          status: PairingStatus.idle,
        );
      }
      throw Exception('Failed to initiate pairing');
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<bool> authorizePairing(String pairingId, {String? deviceName}) async {
    try {
      final data = await _remoteDataSource.authorize(
        pairingId,
        deviceName ?? 'Mobile Device',
      );
      return data['success'] == true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<Map<String, dynamic>> claimPairing(String pairingId,
      {String? deviceName}) async {
    try {
      final data = await _remoteDataSource.claim(
        pairingId,
        deviceName ?? 'Paired Device',
      );
      return data;
    } catch (e) {
      rethrow;
    }
  }
}
