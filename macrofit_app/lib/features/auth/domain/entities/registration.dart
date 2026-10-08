import 'role.dart';

/// Datos de registro ya validados por la app (HU-01).
/// La confirmación de contraseña no viaja al backend.
class Registration {
  const Registration({
    required this.name,
    required this.email,
    required this.password,
    required this.role,
    required this.privacyAccepted,
  });

  final String name;
  final String email;
  final String password;
  final Role role;
  final bool privacyAccepted;
}
