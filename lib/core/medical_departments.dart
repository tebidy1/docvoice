// Re-export MedicalDepartment from the service
export 'package:soutnote/services/medical_departments.dart';

import 'package:soutnote/services/medical_department_service.dart';

/// @deprecated Use MedicalDepartmentService from medical_department_service.dart
class MedicalDepartments {
  /// Load departments from API
  static Future<void> loadDepartments({String locale = 'en'}) async {
    await MedicalDepartmentService().loadDepartments(locale: locale);
  }

  /// Get all departments
  static List<MedicalDepartment> get all => MedicalDepartmentService().departments;

  /// Find a department by its ID. Returns null if not found.
  static MedicalDepartment? getById(String? id) {
    return MedicalDepartmentService().getById(id);
  }

  /// Template categories that are relevant for each department.
  /// Used to filter the template list in the editor.
  static List<String> getRelevantCategories(String departmentId) {
    return MedicalDepartmentService().getRelevantCategories(departmentId);
  }
}
