// TODO: Move to core/services/ or core/interfaces/ in next refactor pass
import 'dart:async';

enum AuthState {
  unauthenticated,
  authenticating,
  authenticated,
  error,
}

abstract class IAuthService {
  AuthState get currentState;
  Stream<AuthState> get authStateStream;

  Future<bool> login(String email, String password, {String? deviceName});
  Future<bool> register({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
    String? invitationCode,
    String? role,
  });
  Future<void> logout();
  Future<Map<String, dynamic>?> getCurrentUser();
  Future<bool> isAuthenticated();
  bool isAdmin();
  bool isCompanyManager();
  bool isMember();
  Future<bool> authorizePairing(String pairingIdOrCode, {String? deviceName});
  Future<Map<String, dynamic>?> initiateSecurePairing();
  Future<bool> claimPairing(String pairingIdOrCode, {String? deviceName});
  Future<Map<String, dynamic>?> getCompanySettings();
  Future<bool> updateCompanySettings(Map<String, dynamic> settings);
  Future<String?> getAccessToken();
  Future<void> initialize();
}
