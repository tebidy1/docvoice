import '../services/auth_service.dart';

class RegisterUseCase {
  final AuthService _authService;

  RegisterUseCase(this._authService);

  Future<bool> execute({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
    String? invitationCode,
    String? role,
  }) async {
    return await _authService.register(
      name: name,
      email: email,
      password: password,
      passwordConfirmation: passwordConfirmation,
      invitationCode: invitationCode,
      role: role,
    );
  }
}
