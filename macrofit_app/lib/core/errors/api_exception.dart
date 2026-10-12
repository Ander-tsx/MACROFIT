import 'package:dio/dio.dart';

/// Códigos de error que devuelve el backend (`backend/README.md`, "Códigos de error")
/// más los que genera la app cuando no hay respuesta del servidor.
abstract final class ApiErrorCode {
  static const validation = 'VALIDATION_ERROR';
  static const invalidBody = 'INVALID_BODY';
  static const privacyNotAccepted = 'PRIVACY_NOT_ACCEPTED';
  static const emailAlreadyExists = 'EMAIL_ALREADY_EXISTS';
  static const invalidCredentials = 'INVALID_CREDENTIALS';
  static const unauthorized = 'UNAUTHORIZED';
  static const invalidRefreshToken = 'INVALID_REFRESH_TOKEN';
  static const tokenRevoked = 'TOKEN_REVOKED';
  static const forbiddenRole = 'FORBIDDEN_ROLE';
  static const clientNotLinked = 'CLIENT_NOT_LINKED';
  static const profileNotFound = 'PROFILE_NOT_FOUND';
  static const profileAlreadyExists = 'PROFILE_ALREADY_EXISTS';

  /// No se pudo contactar al servidor (sin red, servidor apagado, timeout).
  static const network = 'NETWORK_ERROR';

  /// Respuesta inesperada (sin el formato de error de la API).
  static const unknown = 'UNKNOWN_ERROR';
}

/// Error de una llamada a la API con el formato `{ error: { code, message, fields } }`.
///
/// Es la única excepción que las capas de datos dejan salir: los `DioException`
/// se traducen aquí para que dominio y presentación no dependan de Dio.
class ApiException implements Exception {
  const ApiException({
    required this.code,
    required this.message,
    this.fields = const {},
    this.statusCode,
  });

  factory ApiException.fromDio(DioException error) {
    final response = error.response;
    if (response == null) {
      return const ApiException(
        code: ApiErrorCode.network,
        message: 'No pudimos conectar con el servidor. Revisa tu conexión e inténtalo de nuevo.',
      );
    }

    final body = response.data;
    if (body is Map<String, dynamic> && body['error'] is Map<String, dynamic>) {
      final apiError = body['error'] as Map<String, dynamic>;
      final rawFields = apiError['fields'];
      return ApiException(
        code: apiError['code'] as String? ?? ApiErrorCode.unknown,
        message: apiError['message'] as String? ?? _unknownMessage,
        fields: rawFields is Map<String, dynamic>
            ? rawFields.map((key, value) => MapEntry(key, value.toString()))
            : const {},
        statusCode: response.statusCode,
      );
    }

    return ApiException(
      code: ApiErrorCode.unknown,
      message: _unknownMessage,
      statusCode: response.statusCode,
    );
  }

  static const _unknownMessage =
      'Ocurrió un error inesperado. Inténtalo de nuevo.';

  /// Código de la API (`ApiErrorCode`).
  final String code;

  /// Mensaje listo para mostrar.
  final String message;

  /// Errores por campo (nombre del campo en la API → mensaje).
  final Map<String, String> fields;

  /// Código HTTP; `null` si no hubo respuesta.
  final int? statusCode;

  bool get isNetwork => code == ApiErrorCode.network;

  @override
  String toString() => 'ApiException($statusCode $code: $message)';
}
