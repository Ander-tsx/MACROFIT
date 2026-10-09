/// Rutas de la app. Usa siempre estas constantes, nunca cadenas sueltas.
abstract final class AppRoutes {
  /// Carga inicial mientras se lee la sesión guardada.
  static const splash = '/';
  static const login = '/login';
  static const register = '/register';
  static const privacyNotice = '/privacy';

  /// Pantalla principal del rol `user`.
  static const userHome = '/user';

  /// HU-03: perfil inicial obligatorio de un usuario sin perfil.
  static const profileSetup = '/profile/setup';

  /// HU-03: edición del perfil ("Mi perfil") del rol `user`.
  static const profileEdit = '/user/profile';

  /// Pantalla principal del rol `coach`.
  static const coachHome = '/coach';

  /// Rutas visibles sin sesión.
  static const public = {login, register, privacyNotice};

  /// Rutas de un usuario con perfil completo (además del aviso de privacidad).
  static const userRoutes = {userHome, profileEdit};
}
