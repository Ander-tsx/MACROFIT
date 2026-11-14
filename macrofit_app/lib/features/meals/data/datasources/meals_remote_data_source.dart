import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../../core/network/dio_factory.dart';
import '../models/meal_estimate_model.dart';
import '../models/meal_model.dart';

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

  /// HU-08 — `POST /meals` con los valores finales y, si los hay, los estimados.
  Future<MealModel> create(NewMealModel meal) => guardApiCall(() async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/meals',
      data: meal.toJson(),
    );
    return MealModel.fromJson(response.data!);
  });

  /// HU-09 — `GET /meals?date=YYYY-MM-DD`: registros del día, del más antiguo al
  /// más reciente. El día es el de la zona horaria de la app (`APP_UTC_OFFSET`).
  Future<List<MealModel>> list(DateTime day) => guardApiCall(() async {
    final response = await _dio.get<List<dynamic>>(
      '/meals',
      queryParameters: {'date': _formatDate(day)},
    );
    return [
      for (final json in response.data!)
        MealModel.fromJson(json as Map<String, dynamic>),
    ];
  });

  /// HU-09 — `DELETE /meals/{id}` (`204`). También borra su foto en el backend.
  Future<void> delete(String id) => guardApiCall(() async {
    await _dio.delete<void>('/meals/$id');
  });

  /// HU-09 — `GET /meals/photos/{id}`: la foto de un registro propio, con la sesión.
  Future<Uint8List> photo(String photoId) => guardApiCall(() async {
    final response = await _dio.get<List<int>>(
      '/meals/photos/$photoId',
      options: Options(responseType: ResponseType.bytes),
    );
    return Uint8List.fromList(response.data!);
  });

  /// `YYYY-MM-DD`.
  static String _formatDate(DateTime date) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${date.year}-${two(date.month)}-${two(date.day)}';
  }
}
