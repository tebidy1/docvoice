class User {
  final int id;
  final String name;
  final String email;
  final String? phone;
  final int? companyId;
  final String? companyName;
  final String role;
  final String? status;
  final bool isOnline;
  final DateTime? lastSeen;
  final String? profileImageUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  User({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.companyId,
    this.companyName,
    this.role = 'member',
    this.status,
    this.isOnline = false,
    this.lastSeen,
    this.profileImageUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
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
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'company_id': companyId,
      'role': role,
      'status': status,
      'is_online': isOnline,
      'last_seen': lastSeen?.toIso8601String(),
      'profile_image_url': profileImageUrl,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  bool get isAdmin => role.toLowerCase() == 'admin';
  bool get isCompanyManager => role == 'company_manager';
  bool get isMember => role == 'member';
  bool get isActive => status == 'active';

  User copyWith({
    int? id,
    String? name,
    String? email,
    String? phone,
    int? companyId,
    String? companyName,
    String? role,
    String? status,
    bool? isOnline,
    DateTime? lastSeen,
    String? profileImageUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      companyId: companyId ?? this.companyId,
      companyName: companyName ?? this.companyName,
      role: role ?? this.role,
      status: status ?? this.status,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
