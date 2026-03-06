import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class DepartmentService extends ValueNotifier<String?> {
  static final DepartmentService _instance = DepartmentService._internal();
  factory DepartmentService() => _instance;

  DepartmentService._internal() : super(null) {
    _init();
  }

  static const String _prefKey = 'medical_department';

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    value = prefs.getString(_prefKey);
    
    // Attempt to sync from server if logged in
    _syncFromServer();
  }

  Future<void> setDepartment(String? departmentId) async {
    value = departmentId;
    final prefs = await SharedPreferences.getInstance();
    
    if (departmentId == null) {
      await prefs.remove(_prefKey);
    } else {
      await prefs.setString(_prefKey, departmentId);
    }
    
    // Sync to server in background
    _syncToServer(departmentId);
  }

  Future<void> _syncFromServer() async {
    try {
      final user = await AuthService().getCurrentUser();
      if (user != null && user.containsKey('department')) {
        final serverDept = user['department'] as String?;
        if (serverDept != null && serverDept != value) {
          // Server preference takes precedence on fresh login/sync
          value = serverDept;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_prefKey, serverDept);
        }
      }
    } catch (e) {
      debugPrint('Error syncing department from server: $e');
    }
  }

  Future<void> _syncToServer(String? departmentId) async {
    try {
      // Get the token from SharedPreferences directly to ensure we have it
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      
      if (token == null || token.isEmpty) return;
      
      // Update the user's profile on the server.
      // Note: This endpoint must be supported by the backend.
      final url = Uri.parse('http://${prefs.getString("server_ip") ?? "127.0.0.1"}:8000/api/auth/profile/department');
      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
        body: jsonEncode({'department': departmentId}),
      );
      
      if (response.statusCode != 200) {
        debugPrint('Failed to sync department to server: \${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error syncing department to server: $e');
    }
  }
}
