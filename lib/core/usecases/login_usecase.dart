import '../repositories/i_auth_service.dart';
import '../services/auth_service.dart';

class LoginUseCase {
  final AuthService _authService;

  LoginUseCase(this._authService);

  Future<bool> execute(String email, String password,
      {String? deviceName}) async {
    return await _authService.login(email, password, deviceName: deviceName);
  }
}
