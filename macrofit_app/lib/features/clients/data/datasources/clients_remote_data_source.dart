import 'package:dio/dio.dart';

import '../../../../core/network/dio_factory.dart';
import '../models/client_summary_model.dart';

/// Endpoints de clientes del coach (HU-24). Usa el cliente HTTP **con** `AuthInterceptor`.
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
}
