import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/session_model.dart';
import '../models/user_model.dart';

/// Sesión guardada en el dispositivo.
class StoredSession {
  const StoredSession({required this.tokens, required this.user});

  final TokenPair tokens;
  final UserModel user;
}

/// Guarda la sesión en el almacenamiento seguro del sistema operativo
/// (Keychain en iOS, Keystore en Android). Nada de sesión va en
/// SharedPreferences ni en archivos.
class SessionLocalDataSource {
  const SessionLocalDataSource(this._storage);

  final FlutterSecureStorage _storage;

  static const _accessTokenKey = 'auth.access_token';
  static const _refreshTokenKey = 'auth.refresh_token';
  static const _userKey = 'auth.user';

  Future<String?> readAccessToken() => _storage.read(key: _accessTokenKey);

  Future<String?> readRefreshToken() => _storage.read(key: _refreshTokenKey);

  /// Sesión completa, o `null` si falta cualquier parte o está corrupta.
  Future<StoredSession?> read() async {
    final access = await readAccessToken();
    final refresh = await readRefreshToken();
    final userJson = await _storage.read(key: _userKey);
    if (access == null || refresh == null || userJson == null) return null;
    try {
      final user = UserModel.fromJson(
        jsonDecode(userJson) as Map<String, dynamic>,
      );
      return StoredSession(
        tokens: TokenPair(accessToken: access, refreshToken: refresh),
        user: user,
      );
    } on Object {
      return null;
    }
  }

  Future<void> save(SessionModel session) async {
    await saveTokens(session.tokens);
    await saveUser(session.user);
  }

  Future<void> saveTokens(TokenPair tokens) async {
    await _storage.write(key: _accessTokenKey, value: tokens.accessToken);
    await _storage.write(key: _refreshTokenKey, value: tokens.refreshToken);
  }

  Future<void> saveUser(UserModel user) =>
      _storage.write(key: _userKey, value: jsonEncode(user.toJson()));

  Future<void> clear() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _userKey);
  }
}
