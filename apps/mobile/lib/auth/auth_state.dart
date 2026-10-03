enum AuthStatus {
  unauthenticated,
  guest,
  authenticated,
}

class AuthUser {
  final String id;
  final String? email;
  final String? name;
  final bool isAnonymous;
  final String householdId;
  final DateTime createdAt;

  const AuthUser({
    required this.id,
    this.email,
    this.name,
    required this.isAnonymous,
    required this.householdId,
    required this.createdAt,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'] as String,
      email: json['email'] as String?,
      name: json['name'] as String?,
      isAnonymous: json['isAnonymous'] as bool? ?? false,
      householdId: json['householdId'] as String,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'name': name,
        'isAnonymous': isAnonymous,
        'householdId': householdId,
        'createdAt': createdAt.toIso8601String(),
      };
}

class AuthSession {
  final AuthUser user;
  final String accessToken;
  final String refreshToken;
  final int expiresIn;

  const AuthSession({
    required this.user,
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
  });
}
