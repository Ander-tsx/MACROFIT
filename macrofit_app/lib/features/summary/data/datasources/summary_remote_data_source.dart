import 'package:dio/dio.dart';

import '../../../../core/network/dio_factory.dart';
import '../models/day_summary_model.dart';

/// Endpoints de resúmenes (rol `user`). Usa el cliente HTTP **con** `AuthInterceptor`.
class SummaryRemoteDataSource {
  const SummaryRemoteDataSource(this._dio);

  final Dio _dio;

  /// HU-10 — `GET /users/me/summary/daily?date=YYYY-MM-DD`.
  Future<DaySummaryModel> getDaily(String date) => guardApiCall(() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/users/me/summary/daily',
      queryParameters: {'date': date},
    );
    return DaySummaryModel.fromJson(response.data!);
  });
}
