import 'package:flutter/foundation.dart';

import '../entities/auth_state.dart';
import '../entities/registration.dart';
import '../entities/user.dart';

/// Contrato de autenticación y fuente de verdad de la sesión.
///
/// Es un [ChangeNotifier]: cuando [state] cambia (login, logout, sesión
/// expirada) notifica, y el router redirige a la pantalla que corresponde.
/// Los métodos lanzan `ApiException` ante errores de la API o de red.
abstract class AuthRepository extends ChangeNotifier {
  AuthState get state;

  /// Usuario de la sesión activa, o `null`.
  User? get currentUser => switch (state) {
    Authenticated(:final user) => user,
    _ => null,
  };

  /// Lee la sesión guardada en el dispositivo al abrir la app y la valida con
  /// el backend en segundo plano (renovando el access token si expiró).
  Future<void> restoreSession();

  /// HU-01: crea la cuenta. No inicia sesión.
  Future<User> register(Registration registration);

  /// HU-02: inicia sesión y guarda los tokens en almacenamiento seguro.
  Future<User> login({required String email, required String password});

  /// HU-02: cierra la sesión en el backend y borra la sesión local.
  /// La sesión local se borra aunque el servidor no responda.
  Future<void> logout();

  /// HU-03: el perfil inicial se guardó en el backend. Actualiza la sesión
  /// (estado y almacenamiento seguro) para que el router abra la pantalla principal.
  Future<void> markProfileCompleted();
}
