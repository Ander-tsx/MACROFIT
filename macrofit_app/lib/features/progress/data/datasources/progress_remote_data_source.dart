import 'package:dio/dio.dart';

import '../../../../core/network/dio_factory.dart';
import '../models/progress_model.dart';

/// HU-22 — series de progreso. Usa el cliente HTTP **con** `AuthInterceptor`.
class ProgressRemoteDataSource {
  const ProgressRemoteDataSource(this._dio);

  final Dio _dio;

  /// `GET /users/me/progress?from=&to=`.
  Future<ProgressModel> getProgress({
    required String from,
    required String to,
  }) => guardApiCall(() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/users/me/progress',
      queryParameters: {'from': from, 'to': to},
    );
    return ProgressModel.fromJson(response.data!);
  });
}
