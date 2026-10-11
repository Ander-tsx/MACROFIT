import 'role.dart';

/// Cuenta autenticada. Nunca contiene la contraseña ni los tokens.
class User {
  const User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.profileCompleted,
  });

  final String id;
  final String name;
  final String email;
  final Role role;

  /// `false` hasta que la persona capture su perfil (HU-03).
  final bool profileCompleted;

  User copyWith({bool? profileCompleted}) => User(
    id: id,
    name: name,
    email: email,
    role: role,
    profileCompleted: profileCompleted ?? this.profileCompleted,
  );

  @override
  bool operator ==(Object other) =>
      other is User &&
      other.id == id &&
      other.name == name &&
      other.email == email &&
      other.role == role &&
      other.profileCompleted == profileCompleted;

  @override
  int get hashCode => Object.hash(id, name, email, role, profileCompleted);
}
