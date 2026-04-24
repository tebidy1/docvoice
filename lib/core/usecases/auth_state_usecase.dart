import '../repositories/i_auth_service.dart';

class AuthStateUseCase {
  final IAuthService _authService;

  AuthStateUseCase(this._authService);

  Future<bool> isAuthenticated() async {
    return await _authService.isAuthenticated();
  }

  bool isAdmin() {
    return _authService.isAdmin();
  }

  bool isCompanyManager() {
    return _authService.isCompanyManager();
  }

  bool isMember() {
    return _authService.isMember();
  }

  Future<Map<String, dynamic>?> getCurrentUser() async {
    return await _authService.getCurrentUser();
  }
}
