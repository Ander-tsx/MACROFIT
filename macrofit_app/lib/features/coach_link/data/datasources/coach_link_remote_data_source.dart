import 'package:dio/dio.dart';

import '../../../../core/network/dio_factory.dart';
import '../models/coach_link_model.dart';

/// Endpoints de vinculación con el coach (HU-13, HU-14). Usa el cliente HTTP
/// **con** `AuthInterceptor`.
class CoachLinkRemoteDataSource {
  const CoachLinkRemoteDataSource(this._dio);

  final Dio _dio;

  /// `POST /users/me/coach-link`.
  Future<CoachLinkModel> linkCoach(String inviteCode) => guardApiCall(() async {
        final response = await _dio.post<Map<String, dynamic>>(
          '/users/me/coach-link',
          data: {'invite_code': inviteCode},
        );
        return CoachLinkModel.fromJson(response.data!);
      });

  /// `DELETE /users/me/coach-link`.
  Future<void> unlinkCoach() => guardApiCall(() async {
        await _dio.delete<void>('/users/me/coach-link');
      });
}
