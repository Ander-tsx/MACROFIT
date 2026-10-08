import '../../domain/entities/role.dart';
import '../../domain/entities/user.dart';

/// Representación JSON de una cuenta (`UserResponse` del backend).
class UserModel {
  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.profileCompleted,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
    id: json['id'] as String,
    name: json['name'] as String,
    email: json['email'] as String,
    role: json['role'] as String,
    profileCompleted: json['profile_completed'] as bool,
  );

  final String id;
  final String name;
  final String email;
  final String role;
  final bool profileCompleted;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'role': role,
    'profile_completed': profileCompleted,
  };

  User toEntity() => User(
    id: id,
    name: name,
    email: email,
    role: Role.fromApi(role),
    profileCompleted: profileCompleted,
  );
}
