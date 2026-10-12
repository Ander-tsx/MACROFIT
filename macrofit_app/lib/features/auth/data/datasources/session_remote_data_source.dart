import 'package:dio/dio.dart';

import '../../../../core/network/dio_factory.dart';
import '../models/user_model.dart';

/// Endpoints que requieren sesión. Usa el cliente HTTP **con** `AuthInterceptor`,
/// que agrega el Bearer y renueva el access token si expiró.
class SessionRemoteDataSource {
  const SessionRemoteDataSource(this._dio);

  final Dio _dio;

  /// HU-02 — `GET /auth/me`.
  Future<UserModel> me() => guardApiCall(() async {
    final response = await _dio.get<Map<String, dynamic>>('/auth/me');
    return UserModel.fromJson(response.data!);
  });

  /// HU-02 — `POST /auth/logout`. Revoca la sesión en el backend (204).
  Future<void> logout(String refreshToken) => guardApiCall(() async {
    await _dio.post<void>(
      '/auth/logout',
      data: {'refresh_token': refreshToken},
    );
  });
}
