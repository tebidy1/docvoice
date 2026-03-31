class Company {
  final int id;
  final String name;
  final String? domain;
  final String? invitationCode;
  final String? code;
  final String planType;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int? usersCount;

  Company({
    required this.id,
    required this.name,
    this.domain,
    this.invitationCode,
    this.code,
    this.planType = 'basic',
    this.status = 'active',
    required this.createdAt,
    required this.updatedAt,
    this.usersCount,
  });

  factory Company.fromJson(Map<String, dynamic> json) {
    return Company(
      id: json['id'] as int,
      name: json['name'] as String,
      domain: json['domain'] as String?,
      invitationCode: json['invitation_code'] as String?,
      code: json['code'] as String?,
      planType: json['plan_type'] as String? ?? 'basic',
      status: json['status'] as String? ?? 'active',
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      usersCount: json['users_count'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'domain': domain,
      'invitation_code': invitationCode,
      'code': code,
      'plan_type': planType,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  bool get isActive => status == 'active';
  bool get isSuspended => status == 'suspended';

  Company copyWith({
    int? id,
    String? name,
    String? domain,
    String? invitationCode,
    String? code,
    String? planType,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? usersCount,
  }) {
    return Company(
      id: id ?? this.id,
      name: name ?? this.name,
      domain: domain ?? this.domain,
      invitationCode: invitationCode ?? this.invitationCode,
      code: code ?? this.code,
      planType: planType ?? this.planType,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      usersCount: usersCount ?? this.usersCount,
    );
  }
}

