import '../entities/pairing_session.dart';

abstract class PairingRepository {
  Future<PairingSession> initiatePairing();
  Future<Map<String, dynamic>> checkStatus(String pairingId);
  Future<bool> authorizePairing(String pairingId, {String? deviceName});
  Future<Map<String, dynamic>> claimPairing(String pairingId,
      {String? deviceName});
}
