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
