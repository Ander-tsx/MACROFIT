/// Rutas de la app. Usa siempre estas constantes, nunca cadenas sueltas.
abstract final class AppRoutes {
  /// Carga inicial mientras se lee la sesión guardada.
  static const splash = '/';
  static const login = '/login';
  static const register = '/register';
  static const privacyNotice = '/privacy';

  /// Pantalla principal del rol `user`.
  static const userHome = '/user';

  /// Pantalla principal del rol `coach`.
  static const coachHome = '/coach';

  /// Rutas visibles sin sesión.
  static const public = {login, register, privacyNotice};
}
