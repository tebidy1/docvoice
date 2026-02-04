import '../interfaces/dto_mapper.dart';
import '../../models/user.dart';
import 'enhanced_dto_mapper.dart';
import 'mapping_utils.dart';

/// Data Transfer Object for User
class UserDto {
  final Map<String, dynamic> data;
  
  const UserDto(this.data);
  
  /// Create from JSON response
  factory UserDto.fromJson(Map<String, dynamic> json) {
    return UserDto(json);
  }
  
  /// Convert to JSON for API request
  Map<String, dynamic> toJson() => data;
  
  /// Get field value
  T? get<T>(String key) {
    final value = data[key];
    return value is T ? value : null;
  }
}

/// Enhanced mapper for User DTO with nested structure handling
class UserDtoMapper extends EnhancedDtoMapper<User, UserDto> with CommonFieldTransformers {
  @override
  Map<String, NestedTransformer> get nestedTransformers => {
    ...dateTransformers,
    ...booleanTransformers,
    ...integerTransformers,
    'company': CompanyNestedTransformer(),
  };
  
  @override
  List<String> get requiredFields => ['name', 'email'];
  
  @override
  Map<String, dynamic> extractDataFromDto(UserDto dto) => dto.data;
  
  @override
  Map<String, dynamic> extractDataFromEntity(User entity) => {
    'id': entity.id,
    'name': entity.name,
    'email': entity.email,
    if (entity.phone != null) 'phone': entity.phone,
    if (entity.companyId != null) 'company_id': entity.companyId,
    'role': entity.role,
    if (entity.status != null) 'status': entity.status,
    'is_online': entity.isOnline,
    if (entity.lastSeen != null) 'last_seen': entity.lastSeen!.toIso8601String(),
    if (entity.profileImageUrl != null) 'profile_image_url': entity.profileImageUrl,
    'created_at': entity.createdAt.toIso8601String(),
    'updated_at': entity.updatedAt.toIso8601String(),
  };
  
  @override
  User createEntityFromData(Map<String, dynamic> data) {
    return User(
      id: MappingUtils.getNestedValue<int>(data, 'id') ?? 0,
      name: MappingUtils.getNestedValue<String>(data, 'name') ?? '',
      email: MappingUtils.getNestedValue<String>(data, 'email') ?? '',
      phone: MappingUtils.getNestedValue<String>(data, 'phone'),
      companyId: MappingUtils.getNestedValue<int>(data, 'company_id') ?? 
                 MappingUtils.getNestedValue<int>(data, 'company.id'),
      companyName: MappingUtils.getNestedValue<String>(data, 'company_name') ??
                   MappingUtils.getNestedValue<String>(data, 'company.name'),
      role: MappingUtils.getNestedValue<String>(data, 'role') ?? 'member',
      status: MappingUtils.getNestedValue<String>(data, 'status'),
      isOnline: MappingUtils.getNestedValue<bool>(data, 'is_online') ?? false,
      lastSeen: MappingUtils.getNestedValue<DateTime>(data, 'last_seen'),
      profileImageUrl: MappingUtils.getNestedValue<String>(data, 'profile_image_url'),
      createdAt: MappingUtils.getNestedValue<DateTime>(data, 'created_at') ?? DateTime.now(),
      updatedAt: MappingUtils.getNestedValue<DateTime>(data, 'updated_at') ?? DateTime.now(),
    );
  }
  
  @override
  UserDto createDtoFromData(Map<String, dynamic> data) {
    return UserDto(data);
  }
  
  @override
  ValidationResult validateCustomFields(Map<String, dynamic> data, {required bool isDto}) {
    final errors = <String>[];
    
    final name = MappingUtils.getNestedValue<String>(data, 'name');
    if (name != null && name.length > 255) {
      errors.add('Name must be 255 characters or less');
    }
    
    final email = MappingUtils.getNestedValue<String>(data, 'email');
    if (email != null && !_isValidEmail(email)) {
      errors.add('Invalid email format');
    }
    
    final role = MappingUtils.getNestedValue<String>(data, 'role');
    if (role != null && !_isValidRole(role)) {
      errors.add('Invalid role. Must be one of: admin, company_manager, member');
    }
    
    final phone = MappingUtils.getNestedValue<String>(data, 'phone');
    if (phone != null && phone.isNotEmpty && !_isValidPhone(phone)) {
      errors.add('Invalid phone number format');
    }
    
    return errors.isEmpty 
        ? ValidationResult.valid()
        : ValidationResult.invalid(errors);
  }
  
  /// Get company name from nested company object or direct field
  String? _getCompanyName(UserDto dto) {
    final company = dto.get<Map<String, dynamic>>('company');
    if (company != null) {
      return company['name'] as String?;
    }
    return dto.get<String>('company_name');
  }
  
  /// Parse DateTime from string
  DateTime? _parseDateTime(String? dateStr) {
    if (dateStr == null) return null;
    return DateTime.tryParse(dateStr);
  }
  
  /// Validate email format
  bool _isValidEmail(String email) {
    return RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email);
  }
  
  /// Validate role
  bool _isValidRole(String role) {
    const validRoles = ['admin', 'company_manager', 'member'];
    return validRoles.contains(role);
  }
  
  /// Validate phone number format (basic validation)
  bool _isValidPhone(String phone) {
    // Basic phone validation - digits, spaces, hyphens, parentheses, plus
    return RegExp(r'^[\d\s\-\(\)\+]+$').hasMatch(phone) && phone.length >= 10;
  }
}

/// Nested transformer for company objects
class CompanyNestedTransformer implements NestedTransformer {
  @override
  Map<String, dynamic>? transform(dynamic value) {
    if (value == null) return null;
    if (value is Map<String, dynamic>) {
      return {
        'id': value['id'],
        'name': value['name'],
        'domain': value['domain'],
        'plan_type': value['plan_type'],
        'status': value['status'],
      };
    }
    return null;
  }
}