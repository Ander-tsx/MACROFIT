import 'package:dio/dio.dart';

import '../../../../core/network/dio_factory.dart';
import '../models/invite_code_model.dart';

/// Endpoints del código de invitación del coach (HU-12). Usa el cliente HTTP
/// **con** `AuthInterceptor`.
class InviteCodeRemoteDataSource {
  const InviteCodeRemoteDataSource(this._dio);

  final Dio _dio;

  /// `GET /coach/invite-code`.
  Future<InviteCodeModel> getInviteCode() => guardApiCall(() async {
    final response = await _dio.get<Map<String, dynamic>>('/coach/invite-code');
    return InviteCodeModel.fromJson(response.data!);
  });

  /// `POST /coach/invite-code/regenerate` (sin cuerpo).
  Future<InviteCodeModel> regenerateInviteCode() => guardApiCall(() async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/coach/invite-code/regenerate',
    );
    return InviteCodeModel.fromJson(response.data!);
  });
}
