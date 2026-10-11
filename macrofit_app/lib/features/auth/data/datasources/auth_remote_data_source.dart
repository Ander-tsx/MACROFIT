import 'package:dio/dio.dart';

import '../../../../core/network/dio_factory.dart';
import '../../domain/entities/registration.dart';
import '../models/session_model.dart';
import '../models/user_model.dart';

/// Endpoints públicos de autenticación (sin `Authorization`).
/// Usa el cliente HTTP **sin** el interceptor de sesión.
class AuthRemoteDataSource {
  const AuthRemoteDataSource(this._dio);

  final Dio _dio;

  /// HU-01 — `POST /auth/register`.
  Future<UserModel> register(Registration registration) =>
      guardApiCall(() async {
        final response = await _dio.post<Map<String, dynamic>>(
          '/auth/register',
          data: {
            'name': registration.name,
            'email': registration.email,
            'password': registration.password,
            'role': registration.role.apiValue,
            'privacy_accepted': registration.privacyAccepted,
          },
        );
        return UserModel.fromJson(response.data!);
      });

  /// HU-02 — `POST /auth/login`.
  Future<SessionModel> login({
    required String email,
    required String password,
  }) => guardApiCall(() async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/login',
      data: {'email': email, 'password': password},
    );
    return SessionModel.fromJson(response.data!);
  });

  /// HU-02 — `POST /auth/refresh`. Rota el refresh token.
  Future<SessionModel> refresh(String refreshToken) => guardApiCall(() async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/refresh',
      data: {'refresh_token': refreshToken},
    );
    return SessionModel.fromJson(response.data!);
  });
}
