# `lib/core/` — piezas transversales

Código que usan varias features. No contiene lógica de ninguna historia en particular.

| Archivo | Contenido |
|---|---|
| `config/app_config.dart` | `AppConfig.fromEnvironment()`: URL de la API desde `--dart-define=API_BASE_URL` o el backend local por defecto |
| `errors/api_exception.dart` | `ApiException` (`code`, `message`, `fields`, `statusCode`) y `ApiErrorCode` (códigos del backend + `NETWORK_ERROR`, `UNKNOWN_ERROR`) |
| `network/dio_factory.dart` | `createDio(config)` y `guardApiCall`, que traduce `DioException` → `ApiException` |
| `presentation/view_model.dart` | `ViewModel` (base de todos los ViewModels) y `FormStateMixin` (errores por campo, error general, envío) |
| `presentation/widgets/` | Widgets reutilizables: `ErrorBanner`, `PasswordField` |

## Reglas

- **`ApiException` es la única excepción que sale de la capa de datos.** Todas las llamadas remotas van dentro de
  `guardApiCall(() async { ... })`.
- Los códigos de error se comparan con las constantes de `ApiErrorCode`, nunca con cadenas sueltas. Si el backend
  agrega un código, agrégalo aquí.
- Todo ViewModel hereda de `ViewModel`: no notifica después de `dispose` (las acciones async pueden terminar cuando la
  pantalla ya se cerró, p. ej. el login exitoso que navega).
- Formularios: `with FormStateMixin` y `applyApiError(error, knownFields: {...})` para mostrar los errores del backend.
- Un widget va a `core/presentation/widgets/` solo si lo usa más de una feature; si no, vive en la feature.
