class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.displayName,
    required this.status,
    this.username,
    this.avatarUrl,
    this.bio = '',
    this.accountType = 'listener',
    this.locale = 'vi',
    this.timezone = 'Asia/Ho_Chi_Minh',
    this.emailVerifiedAt,
  });

  final String id;
  final String email;
  final String displayName;
  final String? username;
  final String? avatarUrl;
  final String bio;
  final String accountType;
  final String status;
  final String locale;
  final String timezone;
  final DateTime? emailVerifiedAt;

  AuthUser copyWith({
    String? id,
    String? email,
    String? displayName,
    String? username,
    String? avatarUrl,
    String? bio,
    String? accountType,
    String? status,
    String? locale,
    String? timezone,
    DateTime? emailVerifiedAt,
  }) {
    return AuthUser(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      status: status ?? this.status,
      username: username ?? this.username,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bio: bio ?? this.bio,
      accountType: accountType ?? this.accountType,
      locale: locale ?? this.locale,
      timezone: timezone ?? this.timezone,
      emailVerifiedAt: emailVerifiedAt ?? this.emailVerifiedAt,
    );
  }

  String get handle {
    final value = username?.trim();
    if (value != null && value.isNotEmpty) {
      return value;
    }

    final atIndex = email.indexOf('@');
    if (atIndex > 0) {
      return email.substring(0, atIndex);
    }

    return displayName.toLowerCase().replaceAll(' ', '');
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'display_name': displayName,
      'username': username,
      'avatar_url': avatarUrl,
      'bio': bio,
      'account_type': accountType,
      'status': status,
      'locale': locale,
      'timezone': timezone,
      'email_verified_at': emailVerifiedAt?.toIso8601String(),
    };
  }

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      displayName: json['display_name'] as String? ?? '',
      username: json['username'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      bio: json['bio'] as String? ?? '',
      accountType: json['account_type'] as String? ?? 'listener',
      status: json['status'] as String? ?? 'active',
      locale: json['locale'] as String? ?? 'vi',
      timezone: json['timezone'] as String? ?? 'Asia/Ho_Chi_Minh',
      emailVerifiedAt: _parseDateTime(json['email_verified_at']),
    );
  }

  static DateTime? _parseDateTime(Object? value) {
    if (value is! String || value.isEmpty) {
      return null;
    }

    return DateTime.tryParse(value);
  }
}
