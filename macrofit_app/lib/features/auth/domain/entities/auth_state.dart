import 'user.dart';

/// Estado de la sesión. El router lo usa para decidir qué pantalla mostrar.
sealed class AuthState {
  const AuthState();
}

/// Todavía se está leyendo la sesión guardada (pantalla de carga).
final class AuthUnknown extends AuthState {
  const AuthUnknown();
}

/// Hay una sesión activa.
final class Authenticated extends AuthState {
  const Authenticated(this.user);

  final User user;
}

/// No hay sesión: login, registro y aviso de privacidad son las únicas pantallas visibles.
final class Unauthenticated extends AuthState {
  const Unauthenticated();
}
