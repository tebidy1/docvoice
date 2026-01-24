import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final ApiService _apiService = ApiService();
  Map<String, dynamic>? _currentUser;

  Future<bool> login(String email, String password) async {
    try {
      final response = await _apiService.post('/auth/login', body: {
        'email': email,
        'password': password,
      });

      // Laravel API returns success/user/token format
      if (response['success'] == true) {
        String? token = response['token'];
        if (token == null && response['user'] != null && response['user']['token'] != null) {
          token = response['user']['token'];
        }

        if (token != null) {
          await _apiService.setToken(token);
          _currentUser = response['user'] ?? response;
          await _saveUser(_currentUser);
          return true;
        }
      }

      // Fallback for standard API response format
      if (response['status'] == true && response['payload'] != null) {
        final payload = response['payload'];
        
        String? token;
        if (payload['token'] != null) {
          token = payload['token'];
        } else if (payload['access_token'] != null) {
          token = payload['access_token'];
        }

        if (token != null) {
          await _apiService.setToken(token);
          _currentUser = payload['user'] ?? payload;
          await _saveUser(_currentUser);
          return true;
        }
      }

      return false;
    } catch (e) {
      print('Login error: $e');
      return false;
    }
  }

  Future<bool> register({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
    String? invitationCode,
    String? role,
  }) async {
    try {
      final response = await _apiService.post('/auth/register', body: {
        'name': name,
        'email': email,
        'password': password,
        'password_confirmation': passwordConfirmation,
        if (invitationCode != null && invitationCode.isNotEmpty) 'invitation_code': invitationCode,
        if (role != null) 'role': role,
      });

      // Laravel API returns success/user/token format
      if (response['success'] == true) {
        String? token = response['token'];
        if (token == null && response['user'] != null && response['user']['token'] != null) {
          token = response['user']['token'];
        }

        if (token != null) {
          await _apiService.setToken(token);
          _currentUser = response['user'] ?? response;
          await _saveUser(_currentUser);
          return true;
        }
      }

      // Fallback for standard API response format
      if (response['status'] == true && response['payload'] != null) {
        final payload = response['payload'];
        
        String? token;
        if (payload['token'] != null) {
          token = payload['token'];
        } else if (payload['access_token'] != null) {
          token = payload['access_token'];
        }

        if (token != null) {
          await _apiService.setToken(token);
          _currentUser = payload['user'] ?? payload;
          await _saveUser(_currentUser);
          return true;
        }
      }

      return false;
    } catch (e) {
      print('Register error: $e');
      rethrow;
    }
  }

  Future<void> logout() async {
    try {
      await _apiService.post('/auth/logout');
    } catch (e) {
      print('Logout error: $e');
    } finally {
      await _apiService.setToken(null);
      _currentUser = null;
      await _clearUser();
    }
  }

  Future<Map<String, dynamic>?> getCurrentUser() async {
    if (_currentUser != null) {
      return _currentUser;
    }

    try {
      final response = await _apiService.get('/auth/profile');
      
      // Laravel API format
      if (response['success'] == true && response['user'] != null) {
        _currentUser = response['user'];
        await _saveUser(_currentUser);
        return _currentUser;
      }

      // Standard API format
      if (response['status'] == true && response['payload'] != null) {
        _currentUser = response['payload'];
        await _saveUser(_currentUser);
        return _currentUser;
      }
    } catch (e) {
      print('Get current user error: $e');
      // Try to load from storage
      _currentUser = await _loadUser();
    }

    return _currentUser;
  }

  Future<bool> isAuthenticated() async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      return false;
    }

    // Verify token is still valid by getting current user
    try {
      final user = await getCurrentUser();
      return user != null;
    } catch (e) {
      return false;
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
        // Simple parsing - in production, use proper JSON serialization
        return null; // For now, return null and fetch from API
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
