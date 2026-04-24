import '../entities/user.dart';

class UserMapper {
  static final UserMapper _instance = UserMapper._internal();
  factory UserMapper() => _instance;
  UserMapper._internal();

  User fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int,
      name: json['name'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String?,
      companyId: json['company_id'] as int?,
      companyName: json['company'] != null
          ? (json['company'] as Map<String, dynamic>)['name'] as String?
          : null,
      role: json['role'] as String? ?? 'member',
      status: json['status'] as String?,
      isOnline: json['is_online'] as bool? ?? false,
      lastSeen: json['last_seen'] != null
          ? DateTime.parse(json['last_seen'] as String)
          : null,
      profileImageUrl: json['profile_image_url'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson(User user) {
    return {
      'id': user.id,
      'name': user.name,
      'email': user.email,
      'phone': user.phone,
      'company_id': user.companyId,
      'role': user.role,
      'status': user.status,
      'is_online': user.isOnline,
      'last_seen': user.lastSeen?.toIso8601String(),
      'profile_image_url': user.profileImageUrl,
      'created_at': user.createdAt.toIso8601String(),
      'updated_at': user.updatedAt.toIso8601String(),
    };
  }
}
