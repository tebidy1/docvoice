import 'package:flutter/material.dart';

/// A medical department / specialty that users can select in their settings.
class MedicalDepartment {
  final String id;
  final String nameEn;
  final String nameAr;
  final IconData icon;
  final Color color;

  const MedicalDepartment({
    required this.id,
    required this.nameEn,
    required this.nameAr,
    required this.icon,
    required this.color,
  });
}

/// All medical departments sorted by prevalence in Gulf/KSA hospitals.
/// Insurance and Nursing are included at the end as requested.
class MedicalDepartments {
  static const List<MedicalDepartment> all = [
    MedicalDepartment(
      id: 'internal_medicine',
      nameEn: 'Internal Medicine',
      nameAr: 'الطب الباطني',
      icon: Icons.medical_services,
      color: Color(0xFF2196F3),
    ),
    MedicalDepartment(
      id: 'cardiology',
      nameEn: 'Cardiology',
      nameAr: 'أمراض القلب',
      icon: Icons.favorite,
      color: Color(0xFFE53935),
    ),
    MedicalDepartment(
      id: 'emergency',
      nameEn: 'Emergency Medicine',
      nameAr: 'طب الطوارئ',
      icon: Icons.emergency,
      color: Color(0xFFFF5722),
    ),
    MedicalDepartment(
      id: 'general_surgery',
      nameEn: 'General Surgery',
      nameAr: 'الجراحة العامة',
      icon: Icons.content_cut,
      color: Color(0xFF607D8B),
    ),
    MedicalDepartment(
      id: 'orthopedics',
      nameEn: 'Orthopedics',
      nameAr: 'جراحة العظام',
      icon: Icons.accessibility_new,
      color: Color(0xFF795548),
    ),
    MedicalDepartment(
      id: 'ob_gyn',
      nameEn: 'Obstetrics & Gynecology',
      nameAr: 'النساء والتوليد',
      icon: Icons.pregnant_woman,
      color: Color(0xFFE91E63),
    ),
    MedicalDepartment(
      id: 'pediatrics',
      nameEn: 'Pediatrics',
      nameAr: 'طب الأطفال',
      icon: Icons.child_care,
      color: Color(0xFF00BCD4),
    ),
    MedicalDepartment(
      id: 'ophthalmology',
      nameEn: 'Ophthalmology',
      nameAr: 'طب العيون',
      icon: Icons.remove_red_eye,
      color: Color(0xFF00897B),
    ),
    MedicalDepartment(
      id: 'ent',
      nameEn: 'ENT (Ear, Nose & Throat)',
      nameAr: 'الأنف والأذن والحنجرة',
      icon: Icons.hearing,
      color: Color(0xFF5C6BC0),
    ),
    MedicalDepartment(
      id: 'radiology',
      nameEn: 'Radiology',
      nameAr: 'الأشعة',
      icon: Icons.biotech,
      color: Color(0xFF546E7A),
    ),
    MedicalDepartment(
      id: 'anesthesiology',
      nameEn: 'Anesthesiology',
      nameAr: 'التخدير والإنعاش',
      icon: Icons.air,
      color: Color(0xFF9575CD),
    ),
    MedicalDepartment(
      id: 'psychiatry',
      nameEn: 'Psychiatry',
      nameAr: 'الطب النفسي',
      icon: Icons.psychology,
      color: Color(0xFF7E57C2),
    ),
    MedicalDepartment(
      id: 'neurology',
      nameEn: 'Neurology',
      nameAr: 'أمراض الأعصاب',
      icon: Icons.memory,
      color: Color(0xFF3F51B5),
    ),
    MedicalDepartment(
      id: 'neurosurgery',
      nameEn: 'Neurosurgery',
      nameAr: 'جراحة الأعصاب',
      icon: Icons.account_tree,
      color: Color(0xFF283593),
    ),
    MedicalDepartment(
      id: 'urology',
      nameEn: 'Urology',
      nameAr: 'المسالك البولية',
      icon: Icons.water_drop,
      color: Color(0xFF0288D1),
    ),
    MedicalDepartment(
      id: 'nephrology',
      nameEn: 'Nephrology',
      nameAr: 'أمراض الكلى',
      icon: Icons.filter_alt,
      color: Color(0xFF0097A7),
    ),
    MedicalDepartment(
      id: 'gastroenterology',
      nameEn: 'Gastroenterology',
      nameAr: 'أمراض الجهاز الهضمي',
      icon: Icons.restaurant,
      color: Color(0xFF558B2F),
    ),
    MedicalDepartment(
      id: 'pulmonology',
      nameEn: 'Pulmonology',
      nameAr: 'أمراض الرئة والجهاز التنفسي',
      icon: Icons.wind_power,
      color: Color(0xFF039BE5),
    ),
    MedicalDepartment(
      id: 'endocrinology',
      nameEn: 'Endocrinology',
      nameAr: 'الغدد الصماء',
      icon: Icons.science,
      color: Color(0xFFAD1457),
    ),
    MedicalDepartment(
      id: 'oncology',
      nameEn: 'Oncology',
      nameAr: 'الأورام',
      icon: Icons.coronavirus,
      color: Color(0xFF6A1B9A),
    ),
    MedicalDepartment(
      id: 'hematology',
      nameEn: 'Hematology',
      nameAr: 'أمراض الدم',
      icon: Icons.bloodtype,
      color: Color(0xFFC62828),
    ),
    MedicalDepartment(
      id: 'rheumatology',
      nameEn: 'Rheumatology',
      nameAr: 'أمراض الروماتيزم والمفاصل',
      icon: Icons.settings_accessibility,
      color: Color(0xFF4E342E),
    ),
    MedicalDepartment(
      id: 'dermatology',
      nameEn: 'Dermatology',
      nameAr: 'الجلدية',
      icon: Icons.face,
      color: Color(0xFFFF7043),
    ),
    MedicalDepartment(
      id: 'plastic_surgery',
      nameEn: 'Plastic Surgery',
      nameAr: 'جراحة التجميل',
      icon: Icons.auto_fix_high,
      color: Color(0xFFF06292),
    ),
    MedicalDepartment(
      id: 'vascular_surgery',
      nameEn: 'Vascular Surgery',
      nameAr: 'جراحة الأوعية الدموية',
      icon: Icons.linear_scale,
      color: Color(0xFFD32F2F),
    ),
    MedicalDepartment(
      id: 'cardiac_surgery',
      nameEn: 'Cardiac Surgery',
      nameAr: 'جراحة القلب',
      icon: Icons.monitor_heart,
      color: Color(0xFFB71C1C),
    ),
    MedicalDepartment(
      id: 'thoracic_surgery',
      nameEn: 'Thoracic Surgery',
      nameAr: 'جراحة الصدر',
      icon: Icons.airline_seat_recline_normal,
      color: Color(0xFF37474F),
    ),
    MedicalDepartment(
      id: 'colorectal_surgery',
      nameEn: 'Colorectal Surgery',
      nameAr: 'جراحة القولون والمستقيم',
      icon: Icons.loop,
      color: Color(0xFF4CAF50),
    ),
    MedicalDepartment(
      id: 'hepatobiliary',
      nameEn: 'Hepatobiliary Surgery',
      nameAr: 'جراحة الكبد والمرارة',
      icon: Icons.manage_accounts,
      color: Color(0xFF827717),
    ),
    MedicalDepartment(
      id: 'transplant',
      nameEn: 'Transplant Surgery',
      nameAr: 'جراحة الزراعة',
      icon: Icons.swap_horiz,
      color: Color(0xFF1B5E20),
    ),
    MedicalDepartment(
      id: 'spine_surgery',
      nameEn: 'Spine Surgery',
      nameAr: 'جراحة العمود الفقري',
      icon: Icons.straighten,
      color: Color(0xFF263238),
    ),
    MedicalDepartment(
      id: 'maxillofacial',
      nameEn: 'Maxillofacial Surgery',
      nameAr: 'جراحة الفكوك والوجه',
      icon: Icons.face_retouching_natural,
      color: Color(0xFF880E4F),
    ),
    MedicalDepartment(
      id: 'diabetes',
      nameEn: 'Diabetes & Endocrine',
      nameAr: 'السكري والغدد',
      icon: Icons.monitor,
      color: Color(0xFF1565C0),
    ),
    MedicalDepartment(
      id: 'infectious_disease',
      nameEn: 'Infectious Disease',
      nameAr: 'الأمراض المعدية',
      icon: Icons.bug_report,
      color: Color(0xFF33691E),
    ),
    MedicalDepartment(
      id: 'allergy_immunology',
      nameEn: 'Allergy & Immunology',
      nameAr: 'الحساسية والمناعة',
      icon: Icons.shield,
      color: Color(0xFF00695C),
    ),
    MedicalDepartment(
      id: 'geriatrics',
      nameEn: 'Geriatrics',
      nameAr: 'طب المسنين',
      icon: Icons.elderly,
      color: Color(0xFF78909C),
    ),
    MedicalDepartment(
      id: 'family_medicine',
      nameEn: 'Family Medicine & GP',
      nameAr: 'طب الأسرة والعيادة العامة',
      icon: Icons.home,
      color: Color(0xFF43A047),
    ),
    MedicalDepartment(
      id: 'rehabilitation',
      nameEn: 'Physical Medicine & Rehab',
      nameAr: 'الطب الطبيعي وإعادة التأهيل',
      icon: Icons.fitness_center,
      color: Color(0xFFF57F17),
    ),
    MedicalDepartment(
      id: 'nutrition',
      nameEn: 'Clinical Nutrition',
      nameAr: 'التغذية الإكلينيكية',
      icon: Icons.restaurant_menu,
      color: Color(0xFF689F38),
    ),
    MedicalDepartment(
      id: 'pathology',
      nameEn: 'Pathology & Lab Medicine',
      nameAr: 'علم الأمراض والمختبر',
      icon: Icons.colorize,
      color: Color(0xFF4527A0),
    ),
    MedicalDepartment(
      id: 'nuclear_medicine',
      nameEn: 'Nuclear Medicine',
      nameAr: 'الطب النووي',
      icon: Icons.energy_savings_leaf,
      color: Color(0xFF00838F),
    ),
    MedicalDepartment(
      id: 'interventional_radiology',
      nameEn: 'Interventional Radiology',
      nameAr: 'الأشعة التداخلية',
      icon: Icons.radar,
      color: Color(0xFF455A64),
    ),
    MedicalDepartment(
      id: 'palliative_care',
      nameEn: 'Palliative Care',
      nameAr: 'الرعاية التلطيفية',
      icon: Icons.spa,
      color: Color(0xFF6D4C41),
    ),
    MedicalDepartment(
      id: 'sports_medicine',
      nameEn: 'Sports Medicine',
      nameAr: 'الطب الرياضي',
      icon: Icons.sports,
      color: Color(0xFF00897B),
    ),
    MedicalDepartment(
      id: 'occupational_medicine',
      nameEn: 'Occupational Medicine',
      nameAr: 'طب العمل والمهن',
      icon: Icons.work,
      color: Color(0xFF37474F),
    ),
    MedicalDepartment(
      id: 'icu',
      nameEn: 'Intensive Care / ICU',
      nameAr: 'العناية المركزة',
      icon: Icons.monitor_heart,
      color: Color(0xFFBF360C),
    ),
    MedicalDepartment(
      id: 'neonatology',
      nameEn: 'Neonatology (NICU)',
      nameAr: 'حديثو الولادة',
      icon: Icons.baby_changing_station,
      color: Color(0xFFEC407A),
    ),
    MedicalDepartment(
      id: 'dentistry',
      nameEn: 'Dentistry',
      nameAr: 'طب الأسنان',
      icon: Icons.medical_information,
      color: Color(0xFF29B6F6),
    ),
    MedicalDepartment(
      id: 'alternative_medicine',
      nameEn: 'Alternative Medicine',
      nameAr: 'الطب البديل والتكميلي',
      icon: Icons.local_florist,
      color: Color(0xFF66BB6A),
    ),
    // --- Non-clinical departments ---
    MedicalDepartment(
      id: 'insurance',
      nameEn: 'Insurance',
      nameAr: 'التأمين الصحي',
      icon: Icons.verified_user,
      color: Color(0xFF0277BD),
    ),
    MedicalDepartment(
      id: 'nursing',
      nameEn: 'Nursing',
      nameAr: 'التمريض',
      icon: Icons.health_and_safety,
      color: Color(0xFF00ACC1),
    ),
  ];

  /// Find a department by its ID. Returns null if not found.
  static MedicalDepartment? getById(String? id) {
    if (id == null || id.isEmpty) return null;
    try {
      return all.firstWhere((d) => d.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Template categories that are relevant for each department.
  /// Used to filter the template list in the editor.
  static List<String> getRelevantCategories(String departmentId) {
    const Map<String, List<String>> categoryMap = {
      'cardiology': ['Cardiology', 'Internal Medicine', 'General', 'ICU'],
      'internal_medicine': ['Internal Medicine', 'General', 'Cardiology', 'Gastroenterology', 'Pulmonology', 'Nephrology'],
      'emergency': ['Emergency', 'General', 'Trauma', 'ICU'],
      'general_surgery': ['Surgery', 'General Surgery', 'General', 'ICU'],
      'orthopedics': ['Orthopedics', 'Rehabilitation', 'General'],
      'ob_gyn': ['Obstetrics', 'Gynecology', 'OB/GYN', 'General', 'NICU'],
      'pediatrics': ['Pediatrics', 'General', 'NICU'],
      'ophthalmology': ['Ophthalmology', 'General'],
      'ent': ['ENT', 'General'],
      'radiology': ['Radiology', 'General'],
      'anesthesiology': ['Anesthesiology', 'ICU', 'General'],
      'psychiatry': ['Psychiatry', 'Mental Health', 'General'],
      'neurology': ['Neurology', 'General', 'ICU'],
      'neurosurgery': ['Neurosurgery', 'Surgery', 'ICU', 'General'],
      'urology': ['Urology', 'Surgery', 'General'],
      'nephrology': ['Nephrology', 'General', 'ICU'],
      'gastroenterology': ['Gastroenterology', 'General'],
      'pulmonology': ['Pulmonology', 'ICU', 'General'],
      'endocrinology': ['Endocrinology', 'Diabetes', 'General'],
      'oncology': ['Oncology', 'Palliative Care', 'General'],
      'hematology': ['Hematology', 'Oncology', 'General'],
      'rheumatology': ['Rheumatology', 'General'],
      'dermatology': ['Dermatology', 'General'],
      'plastic_surgery': ['Plastic Surgery', 'Surgery', 'General'],
      'vascular_surgery': ['Vascular Surgery', 'Surgery', 'General'],
      'cardiac_surgery': ['Cardiac Surgery', 'Cardiology', 'ICU', 'General'],
      'thoracic_surgery': ['Thoracic Surgery', 'Surgery', 'ICU', 'General'],
      'colorectal_surgery': ['Colorectal Surgery', 'Surgery', 'General'],
      'hepatobiliary': ['Hepatobiliary', 'Surgery', 'General'],
      'transplant': ['Transplant', 'Surgery', 'ICU', 'General'],
      'spine_surgery': ['Spine Surgery', 'Orthopedics', 'Surgery', 'General'],
      'maxillofacial': ['Maxillofacial', 'Surgery', 'General'],
      'diabetes': ['Diabetes', 'Endocrinology', 'General'],
      'infectious_disease': ['Infectious Disease', 'General', 'ICU'],
      'allergy_immunology': ['Allergy', 'Immunology', 'General'],
      'geriatrics': ['Geriatrics', 'Internal Medicine', 'General'],
      'family_medicine': ['Family Medicine', 'General', 'Primary Care'],
      'rehabilitation': ['Rehabilitation', 'Physical Therapy', 'General'],
      'nutrition': ['Nutrition', 'General'],
      'pathology': ['Pathology', 'Laboratory', 'General'],
      'nuclear_medicine': ['Nuclear Medicine', 'Radiology', 'General'],
      'interventional_radiology': ['Interventional Radiology', 'Radiology', 'General'],
      'palliative_care': ['Palliative Care', 'Oncology', 'General'],
      'sports_medicine': ['Sports Medicine', 'Orthopedics', 'General'],
      'occupational_medicine': ['Occupational Medicine', 'General'],
      'icu': ['ICU', 'Critical Care', 'General', 'Cardiology', 'Pulmonology'],
      'neonatology': ['NICU', 'Neonatology', 'Pediatrics', 'General'],
      'dentistry': ['Dentistry', 'General'],
      'alternative_medicine': ['Alternative Medicine', 'General'],
      'insurance': ['Insurance', 'General'],
      'nursing': ['Nursing', 'General'],
    };
    return categoryMap[departmentId] ?? ['General'];
  }
}
