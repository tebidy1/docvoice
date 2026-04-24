import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:soutnote/core/network/api_client.dart';
import 'package:soutnote/core/repositories/i_auth_service.dart';

class AuthService implements IAuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final ApiClient _ApiClient = ApiClient();
  Map<String, dynamic>? _currentUser;

  AuthState _currentState = AuthState.unauthenticated;
  final _authStateController = StreamController<AuthState>.broadcast();

  @override
  AuthState get currentState => _currentState;

  @override
  Stream<AuthState> get authStateStream => _authStateController.stream;

  void _setState(AuthState state) {
    _currentState = state;
    _authStateController.add(state);
  }

  @override
  Future<bool> login(String email, String password,
      {String? deviceName}) async {
    _setState(AuthState.authenticating);
    try {
      final response = await _ApiClient.post('/auth/login', body: {
        'email': email,
        'password': password,
        if (deviceName != null) 'device_name': deviceName,
      });

      if (response['success'] == true) {
        String? token = response['token'];
        if (token == null &&
            response['user'] != null &&
            response['user']['token'] != null) {
          token = response['user']['token'];
        }

        if (token != null) {
          await _ApiClient.setToken(token);
          _currentUser = response['user'] ?? response;
          await _saveUser(_currentUser);
          _setState(AuthState.authenticated);
          return true;
        }
      }

      if (response['status'] == true && response['payload'] != null) {
        final payload = response['payload'];

        String? token;
        if (payload['token'] != null) {
          token = payload['token'];
        } else if (payload['access_token'] != null) {
          token = payload['access_token'];
        }

        if (token != null) {
          await _ApiClient.setToken(token);
          _currentUser = payload['user'] ?? payload;
          await _saveUser(_currentUser);
          _setState(AuthState.authenticated);
          return true;
        }
      }

      _setState(AuthState.unauthenticated);
      return false;
    } catch (e) {
      print('Login error: $e');
      _setState(AuthState.error);
      rethrow;
    }
  }

  @override
  Future<bool> register({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
    String? invitationCode,
    String? role,
  }) async {
    _setState(AuthState.authenticating);
    try {
      final response = await _ApiClient.post('/auth/register', body: {
        'name': name,
        'email': email,
        'password': password,
        'password_confirmation': passwordConfirmation,
        if (invitationCode != null && invitationCode.isNotEmpty)
          'invitation_code': invitationCode,
        if (role != null) 'role': role,
      });

      if (response['success'] == true) {
        String? token = response['token'];
        if (token == null &&
            response['user'] != null &&
            response['user']['token'] != null) {
          token = response['user']['token'];
        }

        if (token != null) {
          await _ApiClient.setToken(token);
          _currentUser = response['user'] ?? response;
          await _saveUser(_currentUser);
          _setState(AuthState.authenticated);
          return true;
        }
      }

      if (response['status'] == true && response['payload'] != null) {
        final payload = response['payload'];

        String? token;
        if (payload['token'] != null) {
          token = payload['token'];
        } else if (payload['access_token'] != null) {
          token = payload['access_token'];
        }

        if (token != null) {
          await _ApiClient.setToken(token);
          _currentUser = payload['user'] ?? payload;
          await _saveUser(_currentUser);
          _setState(AuthState.authenticated);
          return true;
        }
      }

      _setState(AuthState.unauthenticated);
      return false;
    } catch (e) {
      print('Register error: $e');
      _setState(AuthState.error);
      rethrow;
    }
  }

  @override
  Future<void> logout() async {
    try {
      await _ApiClient.post('/auth/logout');
    } catch (e) {
      print('Logout error: $e');
    } finally {
      await _ApiClient.setToken(null);
      _currentUser = null;
      await _clearUser();
      _setState(AuthState.unauthenticated);
    }
  }

  @override
  Future<Map<String, dynamic>?> getCurrentUser() async {
    if (_currentUser != null) {
      return _currentUser;
    }

    try {
      final response = await _ApiClient.get('/auth/profile');

      if (response['success'] == true && response['user'] != null) {
        _currentUser = response['user'];
        await _saveUser(_currentUser);
        return _currentUser;
      }

      if (response['status'] == true && response['payload'] != null) {
        _currentUser = response['payload'];
        await _saveUser(_currentUser);
        return _currentUser;
      }
    } catch (e) {
      print('Get current user error: $e');
      _currentUser = await _loadUser();
    }

    return _currentUser;
  }

  @override
  bool isAdmin() {
    if (_currentUser == null) return false;
    final role = _currentUser!['role']?.toString().toLowerCase();
    return role == 'admin';
  }

  @override
  bool isCompanyManager() {
    if (_currentUser == null) return false;
    final role = _currentUser!['role']?.toString().toLowerCase();
    return role == 'company_manager' || role == 'company-manager';
  }

  @override
  bool isMember() {
    if (_currentUser == null) return true;
    final role = _currentUser!['role']?.toString().toLowerCase();
    return role == 'member';
  }

  @override
  Future<bool> isAuthenticated() async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      return false;
    }

    try {
      final user = await getCurrentUser();
      return user != null;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<bool> authorizePairing(String pairingIdOrCode,
      {String? deviceName}) async {
    try {
      final response = await _ApiClient.post('/pairing/authorize', body: {
        'pairing_id': pairingIdOrCode,
        if (deviceName != null) 'device_name': deviceName,
      });

      return response['success'] == true;
    } catch (e) {
      print('Pairing authorization error: $e');
      return false;
    }
  }

  @override
  Future<Map<String, dynamic>?> initiateSecurePairing() async {
    try {
      final response = await _ApiClient.get('/pairing/initiate-secure');
      if (response['success'] == true) {
        return response;
      }
      return null;
    } catch (e) {
      print('Secure pairing init error: $e');
      return null;
    }
  }

  @override
  Future<bool> claimPairing(String pairingIdOrCode,
      {String? deviceName}) async {
    try {
      final response = await _ApiClient.post('/pairing/claim', body: {
        'pairing_id': pairingIdOrCode,
        if (deviceName != null) 'device_name': deviceName,
      });

      if (response['success'] == true && response['token'] != null) {
        final token = response['token'];

        await _ApiClient.setToken(token);
        _currentUser = response['user'];
        await _saveUser(_currentUser);
        _setState(AuthState.authenticated);
        return true;
      }

      return false;
    } catch (e) {
      print('Claim pairing error: $e');
      return false;
    }
  }

  @override
  Future<Map<String, dynamic>?> getCompanySettings() async {
    try {
      final response = await _ApiClient.get('/company/settings');
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
    } catch (e) {
      print('Get company settings error: $e');
      return null;
    }
  }

  @override
  Future<bool> updateCompanySettings(Map<String, dynamic> settings) async {
    try {
      final response =
          await _ApiClient.put('/company/settings', body: settings);
      return response['success'] == true;
    } catch (e) {
      print('Update company settings error: $e');
      rethrow;
    }
  }

  @override
  Future<String?> getAccessToken() async {
    return await _getToken();
  }

  @override
  Future<void> initialize() async {
    final token = await _getToken();
    if (token != null && token.isNotEmpty) {
      _setState(AuthState.authenticated);
    } else {
      _setState(AuthState.unauthenticated);
    }
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<void> _saveUser(Map<String, dynamic>? user) async {
    if (user == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('current_user', user.toString());
  }

  Future<Map<String, dynamic>?> _loadUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userString = prefs.getString('current_user');
      if (userString != null) {
        return null;
      }
    } catch (e) {
      print('Load user error: $e');
    }
    return null;
  }

  Future<void> _clearUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('current_user');
  }
}
