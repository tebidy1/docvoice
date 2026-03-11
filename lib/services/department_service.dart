import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import 'medical_department_service.dart';

/// Legacy department service - now uses MedicalDepartmentService internally
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

    // Load departments from API first
    await MedicalDepartmentService().loadDepartments();

    // Sync from server if logged in
    await _syncFromServer();
  }

  Future<void> setDepartment(String? departmentId) async {
    value = departmentId;
    final prefs = await SharedPreferences.getInstance();

    if (departmentId == null) {
      await prefs.remove(_prefKey);
    } else {
      await prefs.setString(_prefKey, departmentId);
    }

    // Use the new MedicalDepartmentService to update on server
    await MedicalDepartmentService().updateUserDepartment(departmentId ?? '');
  }

  Future<void> _syncFromServer() async {
    try {
      // Use the new MedicalDepartmentService to sync from server
      await MedicalDepartmentService().syncUserDepartment();

      // Get the department ID from MedicalDepartmentService after sync
      final medicalDeptService = MedicalDepartmentService();
      final syncedDeptId = medicalDeptService.selectedDepartment?.id;
      
      if (syncedDeptId != null) {
        value = syncedDeptId;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_prefKey, syncedDeptId);
        return;
      }

      // Fallback: check local value or AuthService user data
      if (value == null) {
        final user = await AuthService().getCurrentUser();
        if (user != null && user.containsKey('department')) {
          final serverDept = user['department'] as String?;
          if (serverDept != null) {
            value = serverDept;
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(_prefKey, serverDept);
          }
        }
      }
    } catch (e) {
      debugPrint('Error syncing department from server: $e');
    }
  }
}
