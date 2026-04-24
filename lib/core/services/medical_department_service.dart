import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';
import '../network/api_client.dart';

/// A medical department / specialty that users can select in their settings.
/// This is fetched from the API only.
class MedicalDepartment {
  final String id;
  final String nameEn;
  final String nameAr;
  final IconData icon;
  final Color color;
  final List<String> relevantCategories;

  const MedicalDepartment({
    required this.id,
    required this.nameEn,
    required this.nameAr,
    required this.icon,
    required this.color,
    this.relevantCategories = const ['General'],
  });

  /// Create from API JSON response
  factory MedicalDepartment.fromJson(Map<String, dynamic> json) {
    return MedicalDepartment(
      id: json['id'] as String,
      nameEn: json['name_en'] as String? ?? json['name_en'] as String,
      nameAr: json['name_ar'] as String? ?? json['name'] as String,
      icon: _iconFromString(json['icon'] as String? ?? 'medical_services'),
      color: _colorFromHex(json['color'] as String? ?? '#2196F3'),
      relevantCategories: (json['relevant_categories'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          ['General'],
    );
  }

  /// Get localized name based on locale
  String getLocalizedName(String locale) {
    return locale == 'ar' ? nameAr : nameEn;
  }

  /// Convert icon name to IconData
  static IconData _iconFromString(String iconName) {
    const iconMap = {
      'medical_services': Icons.medical_services,
      'favorite': Icons.favorite,
      'emergency': Icons.emergency,
      'content_cut': Icons.content_cut,
      'accessibility_new': Icons.accessibility_new,
      'pregnant_woman': Icons.pregnant_woman,
      'child_care': Icons.child_care,
      'remove_red_eye': Icons.remove_red_eye,
      'hearing': Icons.hearing,
      'biotech': Icons.biotech,
      'air': Icons.air,
      'psychology': Icons.psychology,
      'memory': Icons.memory,
      'account_tree': Icons.account_tree,
      'water_drop': Icons.water_drop,
      'filter_alt': Icons.filter_alt,
      'restaurant': Icons.restaurant,
      'wind_power': Icons.wind_power,
      'science': Icons.science,
      'coronavirus': Icons.coronavirus,
      'bloodtype': Icons.bloodtype,
      'settings_accessibility': Icons.settings_accessibility,
      'face': Icons.face,
      'auto_fix_high': Icons.auto_fix_high,
      'linear_scale': Icons.linear_scale,
      'monitor_heart': Icons.monitor_heart,
      'airline_seat_recline_normal': Icons.airline_seat_recline_normal,
      'loop': Icons.loop,
      'manage_accounts': Icons.manage_accounts,
      'swap_horiz': Icons.swap_horiz,
      'straighten': Icons.straighten,
      'face_retouching_natural': Icons.face_retouching_natural,
      'monitor': Icons.monitor,
      'bug_report': Icons.bug_report,
      'shield': Icons.shield,
      'elderly': Icons.elderly,
      'home': Icons.home,
      'fitness_center': Icons.fitness_center,
      'restaurant_menu': Icons.restaurant_menu,
      'colorize': Icons.colorize,
      'energy_savings_leaf': Icons.energy_savings_leaf,
      'radar': Icons.radar,
      'spa': Icons.spa,
      'sports': Icons.sports,
      'work': Icons.work,
      'baby_changing_station': Icons.baby_changing_station,
      'medical_information': Icons.medical_information,
      'local_florist': Icons.local_florist,
      'verified_user': Icons.verified_user,
      'health_and_safety': Icons.health_and_safety,
    };
    return iconMap[iconName] ?? Icons.medical_services;
  }

  /// Convert hex color string to Color
  static Color _colorFromHex(String hex) {
    hex = hex.replaceFirst('#', '');
    if (hex.length == 6) {
      hex = 'FF$hex';
    }
    return Color(int.parse(hex, radix: 16));
  }
}

/// Service to manage medical departments - fetches from API only
class MedicalDepartmentService extends ChangeNotifier {
  static final MedicalDepartmentService _instance =
      MedicalDepartmentService._internal();
  factory MedicalDepartmentService() => _instance;
  MedicalDepartmentService._internal();

  List<MedicalDepartment> _departments = [];
  bool _isLoading = false;
  String? _error;
  MedicalDepartment? _selectedDepartment;
  String? _userDepartmentId;

  List<MedicalDepartment> get departments => _departments;
  bool get isLoading => _isLoading;
  String? get error => _error;
  MedicalDepartment? get selectedDepartment => _selectedDepartment;

  /// Load departments from API only
  Future<void> loadDepartments({String locale = 'en'}) async {
    if (_departments.isNotEmpty) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final apiClient = ApiClient();
      final response = await apiClient.get('/medical-departments');

      if (response['status'] == true && response['payload'] != null) {
        _departments = (response['payload'] as List)
            .map((e) => MedicalDepartment.fromJson(e))
            .toList();
        _isLoading = false;
        notifyListeners();
        return;
      }
    } catch (e) {
      debugPrint('Error loading departments from API: $e');
    }

    // API failed - set error and empty list
    _error = 'Failed to load departments';
    _departments = [];
    _isLoading = false;
    notifyListeners();
  }

  /// Get department by ID
  MedicalDepartment? getById(String? id) {
    if (id == null || id.isEmpty) return null;
    try {
      return _departments.firstWhere((d) => d.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Get relevant categories for a department
  List<String> getRelevantCategories(String departmentId) {
    final department = getById(departmentId);
    return department?.relevantCategories ?? ['General'];
  }

  /// Sync user's department from server
  Future<void> syncUserDepartment() async {
    try {
      final apiClient = ApiClient();
      final response = await apiClient.get('/medical-departments/user/me');

      if (response['status'] == true && response['payload'] != null) {
        _userDepartmentId = response['payload']['id'] as String?;
        _selectedDepartment = getById(_userDepartmentId);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error syncing user department: $e');
    }
  }

  /// Update user's department on server
  Future<bool> updateUserDepartment(String departmentId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final apiClient = ApiClient();

      final response = await apiClient.put(
        '/medical-departments/user/me',
        body: {'department_id': departmentId},
      );

      if (response['status'] == true) {
        _userDepartmentId = departmentId;
        _selectedDepartment = getById(departmentId);

        // Also save locally
        await prefs.setString('medical_department', departmentId);
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('Error updating user department: $e');
    }
    return false;
  }
}
