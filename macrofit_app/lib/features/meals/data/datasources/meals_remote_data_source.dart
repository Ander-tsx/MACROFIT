import 'package:dio/dio.dart';

import '../../../../core/network/dio_factory.dart';
import '../models/meal_estimate_model.dart';

/// Endpoints de registros de comida (rol `user`).
class MealsRemoteDataSource {
  const MealsRemoteDataSource(this._dio);

  final Dio _dio;

  /// HU-07 — `POST /meals/estimate`. El backend espera al proveedor como máximo
  /// 10 s (RNF-01), dentro del tiempo de respuesta general del cliente.
  Future<MealEstimateModel> estimate(String photoId) => guardApiCall(() async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/meals/estimate',
      data: {'photo_id': photoId},
    );
    return MealEstimateModel.fromJson(response.data!);
  });
}
