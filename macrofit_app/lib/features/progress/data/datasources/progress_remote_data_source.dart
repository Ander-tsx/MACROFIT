import 'package:dio/dio.dart';

import '../../../../core/network/dio_factory.dart';
import '../models/progress_model.dart';

/// HU-22 / HU-23 — series de progreso. Usa el cliente HTTP **con**
/// `AuthInterceptor` (sesión del usuario o del coach).
class ProgressRemoteDataSource {
  const ProgressRemoteDataSource(this._dio);

  final Dio _dio;

  /// HU-22 — `GET /users/me/progress?from=&to=`.
  Future<ProgressModel> getProgress({
    required String from,
    required String to,
  }) => _get('/users/me/progress', from: from, to: to);

  /// HU-23 — `GET /coach/clients/{clientId}/progress?from=&to=`.
  Future<ProgressModel> getClientProgress({
    required String clientId,
    required String from,
    required String to,
  }) => _get('/coach/clients/$clientId/progress', from: from, to: to);

  Future<ProgressModel> _get(
    String path, {
    required String from,
    required String to,
  }) => guardApiCall(() async {
    final response = await _dio.get<Map<String, dynamic>>(
      path,
      queryParameters: {'from': from, 'to': to},
    );
    return ProgressModel.fromJson(response.data!);
  });
}
