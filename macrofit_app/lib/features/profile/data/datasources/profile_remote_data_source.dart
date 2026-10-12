import 'package:dio/dio.dart';

import '../../../../core/network/dio_factory.dart';
import '../models/profile_model.dart';

/// Endpoints del perfil (HU-03). Usa el cliente HTTP **con** `AuthInterceptor`.
class ProfileRemoteDataSource {
  const ProfileRemoteDataSource(this._dio);

  final Dio _dio;

  static const _path = '/users/me/profile';

  /// HU-03 — `GET /users/me/profile`.
  Future<ProfileModel> get() => guardApiCall(() async {
    final response = await _dio.get<Map<String, dynamic>>(_path);
    return ProfileModel.fromJson(response.data!);
  });

  /// HU-03 — `POST /users/me/profile` (201).
  Future<ProfileModel> create(ProfileModel profile) => guardApiCall(() async {
    final response = await _dio.post<Map<String, dynamic>>(
      _path,
      data: profile.toJson(),
    );
    return ProfileModel.fromJson(response.data!);
  });

  /// HU-03 — `PATCH /users/me/profile`.
  Future<ProfileModel> update(ProfileModel profile) => guardApiCall(() async {
    final response = await _dio.patch<Map<String, dynamic>>(
      _path,
      data: profile.toJson(),
    );
    return ProfileModel.fromJson(response.data!);
  });
}
