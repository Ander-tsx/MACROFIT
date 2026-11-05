# `lib/core/` — piezas transversales

Código que usan varias features. No contiene lógica de ninguna historia en particular.

| Archivo | Contenido |
|---|---|
| `config/app_config.dart` | `AppConfig.fromEnvironment()`: URL de la API desde `--dart-define=API_BASE_URL` o el backend local por defecto |
| `errors/api_exception.dart` | `ApiException` (`code`, `message`, `fields`, `statusCode`) y `ApiErrorCode` (códigos del backend + `NETWORK_ERROR`, `UNKNOWN_ERROR`) |
| `network/dio_factory.dart` | `createDio(config)` y `guardApiCall`, que traduce `DioException` → `ApiException` |
| `platform/share_service.dart` | `ShareService` (contrato) y `SystemShareService`: portapapeles (`Clipboard`) y hoja de compartir del sistema (`share_plus`) |
| `presentation/view_model.dart` | `ViewModel` (base de todos los ViewModels) y `FormStateMixin` (errores por campo, error general, envío) |
| `presentation/theme/` | Tokens de la guía visual: `app_colors.dart` (paleta, `AppColors`, sombras), `app_tokens.dart` (espaciado, radios, tamaños, vidrio, movimiento), `macro_style.dart`, `app_text.dart`, `theme_context.dart`. Ver la guía en `lib/app/README.md` |
| `presentation/widgets/` | Widgets compartidos de la guía visual (tabla abajo) |

## Reglas

- **`ApiException` es la única excepción que sale de la capa de datos.** Todas las llamadas remotas van dentro de
  `guardApiCall(() async { ... })`.
- Los códigos de error se comparan con las constantes de `ApiErrorCode`, nunca con cadenas sueltas. Si el backend
  agrega un código, agrégalo aquí.
- Todo ViewModel hereda de `ViewModel`: no notifica después de `dispose` (las acciones async pueden terminar cuando la
  pantalla ya se cerró, p. ej. el login exitoso que navega).
- Formularios: `with FormStateMixin` y `applyApiError(error, knownFields: {...})` para mostrar los errores del backend.
- Un widget va a `core/presentation/widgets/` solo si lo usa más de una feature; si no, vive en la feature.

## Widgets compartidos (`presentation/widgets/`)

| Widget | Para qué |
|---|---|
| `PrimaryButton` | **Botón principal**: píldora de 56 px con ícono, estado de carga y variantes `filled`, `tonal`, `outlined`, `ghost`, `danger`, `onColor` |
| `AppHeader` | **Encabezado** de pantallas secundarias: flecha atrás, título grande y acciones |
| `SurfaceCard` / `SectionCard` | Superficie base (30 px, sin borde, sombra suave) y **tarjeta de sección** con título, descripción y acción |
| `EmptyState` | **Estado vacío** (normal o compacto) |
| `LoadingState` / `InlineSpinner` | **Estado de carga** y el indicador pequeño de botones |
| `ErrorState` / `ErrorBanner` / `StatusBanner` | Error de pantalla o tarjeta con **Reintentar**; mensajes en línea de error, éxito, información o advertencia |
| `showConfirmDialog` / `showAppSnackBar` | Diálogo de confirmación (destructivo opcional) y aviso inferior con ícono |
| `AppTextField` / `PasswordField` / `DateField` / `FieldErrorText` | Campos con ícono, unidad y ayuda; contraseña; fecha; error de controles que no son campos |
| `ChoicePills` | Selección única en píldoras (o círculos con `circular`, p. ej. los días de entrenamiento) |
| `PeriodNavigator` | Píldora «Hoy» / semana con anterior y siguiente |
| `StatTile` / `MetricTile` / `LeaderRow` | Mosaico con contorno (cifra + unidad + pie), dato simple y renglón «etiqueta ···· valor» |
| `MacroRings` / `MacroBadge` / `ProgressRing` | Anillos concéntricos de los tres macros, ícono de un macro con su anillo, anillo simple |
| `HighlightCard` | Tarjeta destacada: color de marca sobre una foto tenue (`AppImages`) y su ícono |
| `ListRow` / `ActionTile` | Fila con cuadro, título y acción separada; fila de navegación (`ListTile`) |
| `MealEntryCard` / `DayTotalCard` / `AsyncPhoto` | Registro de comida, total del día y foto que se descarga aparte (meals y clients) |
| `AppAvatar` / `IconBubble` | Avatar Blobatar generado del correo, sin fondo, e ícono en círculo |
| `GlassSurface` | Vidrio líquido (barra inferior) |
| `PressScale` / `withHaptic` / `FadeSlideIn` / `StateSwitcher` / `CountUp` | Retroalimentación al presionar, vibración, entrada escalonada, transición entre estados y cifras que cuentan |
| `ContentWidth` | Limita el ancho en tabletas |

Pruebas de widget en `test/core/presentation/shared_widgets_test.dart`.
