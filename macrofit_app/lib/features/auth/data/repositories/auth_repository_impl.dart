import 'dart:async';

import '../../../../core/errors/api_exception.dart';
import '../../domain/entities/auth_state.dart';
import '../../domain/entities/registration.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_data_source.dart';
import '../datasources/session_local_data_source.dart';
import '../datasources/session_remote_data_source.dart';

class AuthRepositoryImpl extends AuthRepository {
  AuthRepositoryImpl({
    required this._authRemote,
    required this._sessionRemote,
    required this._local,
  });

  final AuthRemoteDataSource _authRemote;
  final SessionRemoteDataSource _sessionRemote;
  final SessionLocalDataSource _local;

  AuthState _state = const AuthUnknown();

  @override
  AuthState get state => _state;

  @override
  Future<void> restoreSession() async {
    final stored = await _local.read();
    if (stored == null) {
      await _local.clear();
      _setState(const Unauthenticated());
      return;
    }

    // Se entra de inmediato con el usuario guardado (funciona sin red) y se
    // valida en segundo plano: si el access token expiró, el interceptor lo renueva.
    _setState(Authenticated(stored.user.toEntity()));
    unawaited(_revalidate());
  }

  Future<void> _revalidate() async {
    try {
      final user = await _sessionRemote.me();
      await _local.saveUser(user);
      if (_state is Authenticated) _setState(Authenticated(user.toEntity()));
    } on ApiException catch (error) {
      // Sin red se conserva la sesión; un 401 (renovación rechazada o sesión
      // revocada) la termina.
      if (error.statusCode == 401) await _endLocalSession();
    }
  }

  @override
  Future<User> register(Registration registration) async {
    final user = await _authRemote.register(registration);
    return user.toEntity();
  }

  @override
  Future<User> login({required String email, required String password}) async {
    final session = await _authRemote.login(email: email, password: password);
    await _local.save(session);
    final user = session.user.toEntity();
    _setState(Authenticated(user));
    return user;
  }

  @override
  Future<void> logout() async {
    try {
      final refreshToken = await _local.readRefreshToken();
      if (refreshToken != null) await _sessionRemote.logout(refreshToken);
    } on ApiException {
      // El cierre local ocurre aunque el servidor falle o no haya red.
    } finally {
      await _endLocalSession();
    }
  }

  /// Llamado por `AuthInterceptor` cuando la sesión deja de ser válida.
  /// La sesión local ya fue borrada por el interceptor.
  void handleSessionExpired() {
    if (_state is! Unauthenticated) _setState(const Unauthenticated());
  }

  Future<void> _endLocalSession() async {
    await _local.clear();
    _setState(const Unauthenticated());
  }

  void _setState(AuthState state) {
    _state = state;
    notifyListeners();
  }
}
