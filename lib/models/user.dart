class User {
  final int? id;
  final String username;
  final String? email;
  final List<String> roles;

  User({this.id, required this.username, this.email, this.roles = const []});

  factory User.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final username = json['username'];
    final email = json['email'];
    final rolesRaw = json['roles'];

    List<String> roles = [];
    if (rolesRaw is List) {
      roles = rolesRaw.map((r) => r.toString()).toList();
    }

    return User(
      id: id is int ? id : (id is String ? int.tryParse(id) : null),
      username: username is String ? username : username?.toString() ?? '',
      email: email is String ? email : email?.toString(),
      roles: roles,
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'username': username, 'email': email, 'roles': roles};
  }

  /// True si el usuario tiene el rol ROLE_ADMIN
  bool get isAdmin => roles.contains('ROLE_ADMIN');

  /// True si el usuario tiene el rol ROLE_MODERATOR
  bool get isModerator => roles.contains('ROLE_MODERATOR');

  bool get isModeratorOrAdmin => isAdmin || isModerator;
}
