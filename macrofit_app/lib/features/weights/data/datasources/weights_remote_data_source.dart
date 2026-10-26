import 'package:dio/dio.dart';

import '../../../../core/network/dio_factory.dart';
import '../models/weight_model.dart';

/// Endpoints del historial y registro de peso (HU-21). Usa el cliente HTTP
/// **con** `AuthInterceptor`.
class WeightsRemoteDataSource {
  const WeightsRemoteDataSource(this._dio);

  final Dio _dio;

  /// `GET /users/me/weights`.
  Future<List<WeightModel>> getWeights() => guardApiCall(() async {
        final response = await _dio.get<List<dynamic>>('/users/me/weights');
        return (response.data ?? [])
            .map((e) => WeightModel.fromJson(e as Map<String, dynamic>))
            .toList();
      });

  /// `POST /users/me/weights`.
  Future<WeightModel> createWeight(double weightKg) => guardApiCall(() async {
        final response = await _dio.post<Map<String, dynamic>>(
          '/users/me/weights',
          data: {'weight_kg': weightKg},
        );
        return WeightModel.fromJson(response.data!);
      });
}
