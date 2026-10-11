import 'package:flutter/foundation.dart';

/// Configuración de la app que depende del entorno.
///
/// La URL del backend se define al compilar:
/// `flutter run --dart-define=API_BASE_URL=http://192.168.1.10:3000/api/v1`.
/// Sin `--dart-define` se usa el backend local: `10.0.2.2` en el emulador de
/// Android (es el `localhost` de la computadora) y `localhost` en lo demás.
class AppConfig {
  const AppConfig({required this.apiBaseUrl});

  factory AppConfig.fromEnvironment() {
    const fromDefine = String.fromEnvironment('API_BASE_URL');
    if (fromDefine.isNotEmpty) return const AppConfig(apiBaseUrl: fromDefine);

    final isAndroid =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    final host = isAndroid ? '10.0.2.2' : 'localhost';
    return AppConfig(apiBaseUrl: 'http://$host:3000/api/v1');
  }

  /// URL base de la API, incluido el prefijo `/api/v1`.
  final String apiBaseUrl;
}
