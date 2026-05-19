class AuthUser {
  final String id;
  final String email;
  final String name;
  final DateTime createdAt;

  const AuthUser({
    required this.id,
    required this.email,
    required this.name,
    required this.createdAt,
  });

  factory AuthUser.fromJson(Map<String, dynamic> j) => AuthUser(
        id: (j['id'] ?? '').toString(),
        email: (j['email'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
        createdAt: DateTime.tryParse((j['created_at'] ?? '').toString()) ??
            DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'name': name,
        'created_at': createdAt.toIso8601String(),
      };

  String get initials {
    final source = name.trim().isNotEmpty ? name.trim() : email;
    final parts = source.split(RegExp(r'[\s@.]+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.elementAt(1).substring(0, 1))
        .toUpperCase();
  }
}
