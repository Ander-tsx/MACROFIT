import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../../core/network/dio_factory.dart';
import '../models/client_meal_model.dart';
import '../models/client_summary_model.dart';

/// Endpoints de clientes del coach (HU-24, HU-25). Usa el cliente HTTP **con** `AuthInterceptor`.
class ClientsRemoteDataSource {
  const ClientsRemoteDataSource(this._dio);

  final Dio _dio;

  /// HU-24 — `GET /coach/clients`.
  Future<List<ClientSummaryModel>> getClients() => guardApiCall(() async {
    final response = await _dio.get<List<dynamic>>('/coach/clients');
    return [
      for (final json in response.data!)
        ClientSummaryModel.fromJson(json as Map<String, dynamic>),
    ];
  });

  /// HU-25 — `GET /coach/clients/{clientId}/meals?date=YYYY-MM-DD`.
  Future<List<ClientMealModel>> getClientMeals(
    String clientId,
    DateTime date,
  ) => guardApiCall(() async {
    final response = await _dio.get<List<dynamic>>(
      '/coach/clients/$clientId/meals',
      queryParameters: {'date': _formatDate(date)},
    );
    return [
      for (final json in response.data!)
        ClientMealModel.fromJson(json as Map<String, dynamic>),
    ];
  });

  /// HU-25 — `GET /meals/photos/{id}` a partir de `photo_url`.
  ///
  /// `photo_url` es una ruta absoluta del servidor (`/api/v1/meals/photos/...`), así que
  /// se resuelve contra el host de la API. Se usa el mismo cliente con sesión: el
  /// `AuthInterceptor` agrega la cabecera `Authorization` del coach.
  Future<Uint8List> getMealPhoto(String photoUrl) => guardApiCall(() async {
    final url = Uri.parse(_dio.options.baseUrl).resolve(photoUrl).toString();
    final response = await _dio.get<List<int>>(
      url,
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
