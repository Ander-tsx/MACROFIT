import '../entities/role.dart';

/// Reglas de validación de HU-01/HU-02. Deben coincidir con las del backend
/// (`backend/src/validation.rs` y `backend/src/services/auth.rs`).
/// Cada función devuelve el mensaje de error o `null` si el valor es válido.
abstract final class AuthValidators {
  static const passwordMinLength = 8;
  static const passwordMaxLength = 128;
  static const nameMaxLength = 100;
  static const emailMaxLength = 254;

  static String? name(String value) {
    final name = value.trim();
    if (name.isEmpty) return 'El nombre es obligatorio';
    if (name.runes.length > nameMaxLength) {
      return 'El nombre no puede superar $nameMaxLength caracteres';
    }
    return null;
  }

  static String? email(String value) {
    final email = value.trim();
    if (email.isEmpty) return 'El correo es obligatorio';
    if (!isValidEmail(email)) return 'El correo no tiene un formato válido';
    return null;
  }

  /// Contraseña nueva (registro).
  static String? newPassword(String value) {
    if (value.isEmpty) return 'La contraseña es obligatoria';
    if (value.runes.length < passwordMinLength) {
      return 'La contraseña debe tener al menos $passwordMinLength caracteres';
    }
    if (value.runes.length > passwordMaxLength) {
      return 'La contraseña no puede superar $passwordMaxLength caracteres';
    }
    return null;
  }

  /// Contraseña en el login: solo obligatoria (las reglas de longitud no se revelan).
  static String? loginPassword(String value) =>
      value.isEmpty ? 'La contraseña es obligatoria' : null;

  static String? passwordConfirmation(String password, String confirmation) {
    if (confirmation.isEmpty) return 'Confirma tu contraseña';
    if (password != confirmation) return 'Las contraseñas no coinciden';
    return null;
  }

  static String? role(Role? value) =>
      value == null ? 'Debes elegir un rol' : null;

  static String? privacyAccepted(bool accepted) =>
      accepted ? null : 'Debes aceptar el aviso de privacidad';

  /// Mismo criterio que `is_valid_email` del backend: `local@dominio.tld`, sin
  /// espacios, un solo `@` y un dominio con al menos un punto.
  static bool isValidEmail(String email) {
    if (email.isEmpty || email.runes.length > emailMaxLength) return false;
    if (email.contains(RegExp(r'\s'))) return false;
    final parts = email.split('@');
    if (parts.length != 2) return false;
    final [local, domain] = parts;
    if (local.isEmpty || domain.startsWith('-') || domain.endsWith('-')) {
      return false;
    }
    final labels = domain.split('.');
    return labels.length >= 2 && labels.every((label) => label.isNotEmpty);
  }
}
