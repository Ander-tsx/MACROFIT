import '../entities/profile.dart';

/// Contrato del perfil del usuario de la sesión (HU-03).
/// Los métodos lanzan `ApiException` ante errores de la API o de red
/// (p. ej. `PROFILE_NOT_FOUND`, `PROFILE_ALREADY_EXISTS`).
abstract interface class ProfileRepository {
  /// `GET /users/me/profile`.
  Future<Profile> getProfile();

  /// `POST /users/me/profile`.
  Future<Profile> createProfile(Profile profile);

  /// `PATCH /users/me/profile`. Envía todos los campos del perfil.
  Future<Profile> updateProfile(Profile profile);
}
