import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../errors/api_exception.dart';

/// Crea un cliente HTTP apuntando a la API. Las respuestas que no son 2xx
/// lanzan `DioException`, que las fuentes de datos traducen con [guardApiCall].
Dio createDio(AppConfig config) {
  return Dio(
    BaseOptions(
      baseUrl: config.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      contentType: Headers.jsonContentType,
      responseType: ResponseType.json,
    ),
  );
}

/// Ejecuta una llamada HTTP y traduce cualquier `DioException` a [ApiException].
/// Todas las fuentes de datos remotas envuelven sus llamadas con esta función.
Future<T> guardApiCall<T>(Future<T> Function() call) async {
  try {
    return await call();
  } on DioException catch (error) {
    throw ApiException.fromDio(error);
  }
}
