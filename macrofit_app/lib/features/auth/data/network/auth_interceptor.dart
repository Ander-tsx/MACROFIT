import 'package:dio/dio.dart';

import '../../../../core/errors/api_exception.dart';
import '../datasources/session_local_data_source.dart';
import '../models/session_model.dart';

/// Interceptor del cliente HTTP con sesión (HU-02).
///
/// - Agrega `Authorization: Bearer <access_token>` a cada petición.
/// - Ante `401 UNAUTHORIZED` (access token expirado o inválido) renueva una sola
///   vez con el refresh token y reintenta la petición original.
/// - Si la renovación es rechazada, o la API responde `401 TOKEN_REVOKED`,
///   borra la sesión local y avisa con [onSessionExpired] (el router manda a login).
/// - Sin red durante la renovación: no borra la sesión; el error sube tal cual.
///
/// Es un [QueuedInterceptor]: los errores se procesan uno por uno, así que si
/// varias peticiones expiran a la vez solo la primera renueva y las demás
/// reutilizan el token nuevo.
class AuthInterceptor extends QueuedInterceptor {
  AuthInterceptor({
    required this._local,
    required this._refresh,
    required this._retryClient,
  });

  final SessionLocalDataSource _local;
  final Future<SessionModel> Function(String refreshToken) _refresh;

  /// Cliente **sin** este interceptor para reintentar (evita bucles y bloqueos de la cola).
  final Dio _retryClient;

  /// Se asigna en la composición de dependencias (`AuthRepositoryImpl.handleSessionExpired`).
  void Function()? onSessionExpired;

  static const _retriedKey = 'auth_retried';

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _local.readAccessToken();
    if (token != null) options.headers['Authorization'] = 'Bearer $token';
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final request = err.requestOptions;
    if (err.response?.statusCode != 401 || request.extra[_retriedKey] == true) {
      return handler.next(err);
    }

    final code = ApiException.fromDio(err).code;
    if (code == ApiErrorCode.tokenRevoked) {
      await _expireSession();
      return handler.next(err);
    }
    if (code != ApiErrorCode.unauthorized) return handler.next(err);

    final newAccessToken = await _renewAccessToken(
      usedHeader: request.headers['Authorization'] as String?,
    );
    if (newAccessToken == null) return handler.next(err);

    request.headers['Authorization'] = 'Bearer $newAccessToken';
    request.extra[_retriedKey] = true;
    try {
      handler.resolve(await _retryClient.fetch<dynamic>(request));
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }

  /// Devuelve un access token nuevo, o `null` si no se pudo renovar.
  Future<String?> _renewAccessToken({required String? usedHeader}) async {
    // Otra petición ya renovó mientras esta esperaba en la cola.
    final current = await _local.readAccessToken();
    if (current != null && usedHeader != 'Bearer $current') return current;

    final refreshToken = await _local.readRefreshToken();
    if (refreshToken == null) {
      await _expireSession();
      return null;
    }

    try {
      final session = await _refresh(refreshToken);
      await _local.save(session);
      return session.tokens.accessToken;
    } on ApiException catch (error) {
      if (!error.isNetwork) await _expireSession();
      return null;
    }
  }

  Future<void> _expireSession() async {
    await _local.clear();
    onSessionExpired?.call();
  }
}
