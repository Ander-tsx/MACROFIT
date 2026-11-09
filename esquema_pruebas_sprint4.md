## Casos de prueba

| Historia de usuario | ¿Qué comprueba? | Tipo | Criterio de aprobación | Pruebas realizadas |
|---|---|---|---|---|
| HU-15 | La rutina recomendada se genera con el objetivo, el nivel y los días del perfil y se guarda con origen `system` (RF-14, RN-08). | Unitaria | El motor recibe objetivo, nivel y días del perfil; la rutina guardada conserva nombre, sesiones numeradas y ejercicios con series, repeticiones y descanso, con `origin: system` y vigente; la respuesta no expone `user_id` ni `status`. | [**3**](#caso-01) (mobile 0 · backend 3) |
| HU-15 | Una sesión por día de entrenamiento, con las 3 divisiones y los 3 niveles del catálogo de TEC-09 (RF-14). | Unitaria | Principiante con 3 días: 3 sesiones de cuerpo completo con 2 series; intermedio con 4: torso y pierna alternados con 3 series; avanzado con 6: empuje, tirón y pierna con 4 series; sesiones numeradas desde 1, nunca más que los días, y solo ejercicios del nivel del usuario o inferiores. | [**5**](#caso-02) (mobile 0 · backend 5) |
| HU-15 | Pedir la rutina otra vez reemplaza la vigente sin borrar la anterior. | Integración | Regenerar devuelve `201` con otro `id`; la anterior queda como `replaced` con su fecha y sus sesiones intactas, hay una sola vigente por usuario y no se toca la rutina de otro usuario. | [**2**](#caso-03) (mobile 0 · backend 2) |
| HU-15 | Errores al generar la rutina. | Integración | Sin perfil responde `404 PROFILE_NOT_FOUND`; un catálogo sin ejercicios elegibles responde `503 EXERCISE_CATALOG_INCOMPLETE` sin perder la rutina vigente; días inválidos son `INTERNAL_ERROR`; una cuenta de coach responde `403 FORBIDDEN_ROLE` y sin sesión `401 UNAUTHORIZED`. | [**8**](#caso-04) (mobile 0 · backend 8) |
| HU-15 | `POST /users/me/routines/recommended` está en el contrato OpenAPI (TEC-14). | Unitaria | La especificación incluye el endpoint con seguridad `bearer_auth` de rol `user` y documenta `201`, `401`, `403`, `404` y `503`, con el cuerpo de la respuesta exitosa. | [**4**](#caso-05) (mobile 0 · backend 4) |
| HU-15 | La app interpreta `POST /users/me/routines/recommended`. | Unitaria | La respuesta `201` da nombre, objetivo, nivel, días y sesiones numeradas con ejercicios, series, repeticiones y descanso; `404 PROFILE_NOT_FOUND` y `503 EXERCISE_CATALOG_INCOMPLETE` salen como `ApiException`. | [**4**](#caso-11) (mobile 4 · backend 0) |
| HU-15 | Solicitar la rutina desde la pantalla principal con estado de carga (RF-14). | Interfaz | La tarjeta **Rutina recomendada** del inicio abre la pantalla; abrirla no genera; mientras se genera se muestra la carga y el botón no envía dos veces. | [**7**](#caso-12) (mobile 7 · backend 0) |
| HU-15 | La rutina se muestra completa (RF-14, RF-15). | Interfaz | Se ven nombre, objetivo, nivel y días, y cada sesión numerada con sus ejercicios, series, repeticiones y descanso. | [**1**](#caso-13) (mobile 1 · backend 0) |
| HU-15 | Generarla de nuevo pide confirmación. | Interfaz | Con una rutina generada o vigente, **Generar de nuevo** pide confirmar porque reemplaza la anterior; cancelar no genera; al confirmar se muestra la nueva; si falla se conserva la que se veía. | [**6**](#caso-14) (mobile 6 · backend 0) |
| HU-15 | Errores sin cerrar la app (RNF-11). | Interfaz | `404 PROFILE_NOT_FOUND` muestra un mensaje que lleva a completar el perfil; el catálogo incompleto y la falta de conexión muestran el mensaje en español y permiten reintentar; si no se pudo revisar la rutina vigente no se ofrece generar. | [**8**](#caso-15) (mobile 8 · backend 0) |
| HU-15 | Ruta de la pantalla. | Unitaria | Solo un usuario con perfil abre `/user/routines/recommended` (un coach, un usuario sin perfil o sin sesión son redirigidos) y no se confunde con el detalle de una rutina. | [**3**](#caso-16) (mobile 3 · backend 0) |

## Cómo se cuentan las pruebas

- **Mobile**: cada `test` o `testWidgets` de `macrofit_app/test/` (Flutter).
- **Backend**: cada prueba unitaria `#[test]` de `backend/src/` (Rust) más cada request de la colección de Postman (`backend/postman/`), que verifica el código de estado y la estructura de la respuesta. Los requests de "Preparación" (crear cuentas o iniciar sesión para los siguientes) no se cuentan.
- Una misma prueba puede contar en más de un caso cuando verifica varios criterios (p. ej. las pruebas generales de TEC-14 cuentan para cada endpoint nuevo del catálogo de `routes/openapi.rs`).
- No se cuentan las pruebas manuales de punta a punta ni las capturas de evidencia.

Inventario al cerrar HU-15-API: **589** pruebas mobile (`flutter test`, sin cambios), **278** pruebas de Rust (`cargo test`: 250 se ejecutan y 28 requieren MongoDB y se ejecutan con `--ignored`) y **252** requests de Postman en la colección combinada (sin contar los 102 de preparación). HU-15-API agrega 10 pruebas de Rust (6 puras y 3 con MongoDB en `services/recommended_routines.rs`, y 1 de la respuesta en `routes/recommended_routines.rs`), amplía la de códigos de error de `error.rs` con `EXERCISE_CATALOG_INCOMPLETE` y agrega el módulo de Postman `recommended_routines` con 7 requests (más 13 de preparación). La colección completa pasó dos veces seguidas con Newman contra una base temporal (358 requests y 979 aserciones por corrida, 0 fallos).
Inventario al cerrar HU-15-APP: **661** pruebas mobile (`flutter test`; 633 en `develop` con HU-16-APP y HU-17-APP). HU-15-APP agrega 28 (3 de datos, 12 del ViewModel, 9 de la pantalla, 2 de rutas y 2 de flujos en `app_test`) y mueve la tarjeta de sesión del detalle de HU-16 al widget compartido `SessionPlanCard`, sin cambiar sus pruebas. Sin cambios en el backend. La prueba de punta a punta en un dispositivo físico contra la API desplegada queda pendiente (no se cuenta).

## Detalle de las pruebas por caso

### <a id="caso-01"></a>Caso 01 · HU-15 — Rutina a partir del perfil con origen `system`

Mobile: 0 · Backend: 3

**Backend (Rust)**

- `backend/src/services/recommended_routines.rs` › `routine_profile_toma_objetivo_nivel_y_dias`
- `backend/src/services/recommended_routines.rs` › `la_rutina_guardada_conserva_sesiones_y_volumen`
- `backend/src/routes/recommended_routines.rs` › `la_respuesta_trae_origen_system_y_sesiones_sin_exponer_datos_internos`

### <a id="caso-02"></a>Caso 02 · HU-15 — Una sesión por día, divisiones y niveles con el catálogo de TEC-09 (RF-14)

Mobile: 0 · Backend: 5

**Backend (Rust)**

- `backend/src/services/recommended_routines.rs` › `divisiones_y_niveles_con_el_catalogo_de_tec09`
- `backend/src/services/recommended_routines.rs` › `solo_usa_ejercicios_del_nivel_o_inferiores`

**Backend (Postman)**

- Postman › HU-15 Rutina recomendada › 01 - Principiante con 3 días: cuerpo completo
- Postman › HU-15 Rutina recomendada › 02 - Intermedio con 4 días: torso y pierna
- Postman › HU-15 Rutina recomendada › 03 - Avanzado con 6 días: empuje, tirón y pierna

### <a id="caso-03"></a>Caso 03 · HU-15 — Regenerar reemplaza la vigente sin borrar la anterior

Mobile: 0 · Backend: 2

Las sesiones completadas (HU-17) viven en su propia colección y apuntan al `_id` de la rutina; como la anterior se
conserva como `replaced`, regenerar no las afecta.

**Backend (Rust)**

- `backend/src/services/recommended_routines.rs` › `mongo::generar_y_regenerar_deja_una_sola_vigente` (requiere MongoDB, `--ignored`)

**Backend (Postman)**

- Postman › HU-15 Rutina recomendada › 04 - Regenerar: reemplaza la rutina anterior

### <a id="caso-04"></a>Caso 04 · HU-15 — Errores al generar la rutina

Mobile: 0 · Backend: 8

El catálogo incompleto no se puede provocar en Postman (el catálogo de TEC-09 tiene todos los grupos y niveles), así
que se prueba en Rust contra MongoDB con el catálogo vacío.

**Backend (Rust)**

- `backend/src/services/recommended_routines.rs` › `catalogo_incompleto_responde_exercise_catalog_incomplete`
- `backend/src/services/recommended_routines.rs` › `dias_invalidos_del_motor_son_error_interno`
- `backend/src/services/recommended_routines.rs` › `mongo::sin_perfil_responde_profile_not_found` (requiere MongoDB, `--ignored`)
- `backend/src/services/recommended_routines.rs` › `mongo::catalogo_vacio_responde_exercise_catalog_incomplete_sin_reemplazar` (requiere MongoDB, `--ignored`)
- `backend/src/error.rs` › `errores_del_reconocimiento_de_alimentos_y_de_rutinas_tienen_su_estado_y_codigo`

**Backend (Postman)**

- Postman › HU-15 Rutina recomendada › 05 - Usuario sin perfil: 404 PROFILE_NOT_FOUND
- Postman › HU-15 Rutina recomendada › 06 - Cuenta de coach: 403 FORBIDDEN_ROLE
- Postman › HU-15 Rutina recomendada › 07 - Sin sesión: 401 UNAUTHORIZED

### <a id="caso-05"></a>Caso 05 · HU-15 — Contrato OpenAPI (TEC-14)

Mobile: 0 · Backend: 4

El endpoint está en el `CATALOG` de `routes/openapi.rs`, así que lo cubren las pruebas generales de TEC-14.

**Backend (Rust)**

- `backend/src/routes/openapi.rs` › `la_especificacion_incluye_todos_los_endpoints_del_catalogo`
- `backend/src/routes/openapi.rs` › `cada_operacion_documenta_sus_codigos_de_estado`
- `backend/src/routes/openapi.rs` › `cada_respuesta_exitosa_documenta_su_cuerpo`
- `backend/src/routes/openapi.rs` › `rutas_protegidas_declaran_bearer_y_rol`

### <a id="caso-11"></a>Caso 11 · HU-15 — Llamada a `POST /users/me/routines/recommended` y modelo de la rutina

Mobile: 4 · Backend: 0

**Mobile**

- `macrofit_app/test/features/my_routines/data/my_routines_repository_impl_test.dart` › pedir la recomendada usa la respuesta de HU-15
- `macrofit_app/test/features/my_routines/data/my_routines_repository_impl_test.dart` › la recomendada trae objetivo, nivel y días, y sesiones numeradas (HU-15)
- `macrofit_app/test/features/my_routines/data/my_routines_repository_impl_test.dart` › 404 PROFILE_NOT_FOUND al pedir la recomendada sale como ApiException
- `macrofit_app/test/features/my_routines/data/my_routines_repository_impl_test.dart` › 503 EXERCISE_CATALOG_INCOMPLETE al pedir la recomendada sale como ApiException

### <a id="caso-12"></a>Caso 12 · HU-15 — Solicitar la rutina con estado de carga (RF-14)

Mobile: 7 · Backend: 0

**Mobile**

- `macrofit_app/test/app/app_test.dart` › rutina recomendada (HU-15) › el inicio del usuario abre la pantalla para solicitarla
- `macrofit_app/test/features/my_routines/presentation/recommended_routine_view_model_test.dart` › al abrir › sin recomendada vigente no hay rutina que reemplazar
- `macrofit_app/test/features/my_routines/presentation/recommended_routine_view_model_test.dart` › al abrir › encuentra la recomendada vigente entre las rutinas
- `macrofit_app/test/features/my_routines/presentation/recommended_routine_view_model_test.dart` › generar › la primera vez no pide confirmación y muestra la rutina
- `macrofit_app/test/features/my_routines/presentation/recommended_routine_view_model_test.dart` › generar › mientras genera está en carga y no envía dos veces
- `macrofit_app/test/features/my_routines/presentation/recommended_routine_view_test.dart` › sin rutina ofrece generarla y abrir no la genera
- `macrofit_app/test/features/my_routines/presentation/recommended_routine_view_test.dart` › mientras se genera hay carga y el botón no envía dos veces

### <a id="caso-13"></a>Caso 13 · HU-15 — La rutina se muestra completa (RF-14, RF-15)

Mobile: 1 · Backend: 0

**Mobile**

- `macrofit_app/test/features/my_routines/presentation/recommended_routine_view_test.dart` › muestra nombre, objetivo, nivel, días y cada sesión

### <a id="caso-14"></a>Caso 14 · HU-15 — Generarla de nuevo pide confirmación

Mobile: 6 · Backend: 0

**Mobile**

- `macrofit_app/test/features/my_routines/presentation/recommended_routine_view_model_test.dart` › generar de nuevo › con una vigente pide confirmación; cancelar no genera
- `macrofit_app/test/features/my_routines/presentation/recommended_routine_view_model_test.dart` › generar de nuevo › al confirmar muestra la nueva
- `macrofit_app/test/features/my_routines/presentation/recommended_routine_view_model_test.dart` › generar de nuevo › la rutina recién generada también pide confirmación
- `macrofit_app/test/features/my_routines/presentation/recommended_routine_view_model_test.dart` › generar de nuevo › si falla conserva la rutina que se estaba viendo
- `macrofit_app/test/features/my_routines/presentation/recommended_routine_view_test.dart` › generarla de nuevo pide confirmación y muestra la nueva
- `macrofit_app/test/features/my_routines/presentation/recommended_routine_view_test.dart` › con una vigente la muestra, la abre y regenerar confirma

### <a id="caso-15"></a>Caso 15 · HU-15 — Errores sin cerrar la app (RNF-11)

Mobile: 8 · Backend: 0

**Mobile**

- `macrofit_app/test/features/my_routines/presentation/recommended_routine_view_model_test.dart` › al abrir › sin conexión muestra el error y permite reintentar
- `macrofit_app/test/features/my_routines/presentation/recommended_routine_view_model_test.dart` › generar › un error conserva la pantalla y permite reintentar
- `macrofit_app/test/features/my_routines/presentation/recommended_routine_view_model_test.dart` › generar › sin perfil lo indica con un mensaje propio
- `macrofit_app/test/features/my_routines/presentation/recommended_routine_view_model_test.dart` › generar › catálogo incompleto muestra el mensaje de la API
- `macrofit_app/test/features/my_routines/presentation/recommended_routine_view_test.dart` › sin perfil muestra el mensaje y lleva a completarlo
- `macrofit_app/test/features/my_routines/presentation/recommended_routine_view_test.dart` › el catálogo incompleto muestra el mensaje y permite reintentar
- `macrofit_app/test/features/my_routines/presentation/recommended_routine_view_test.dart` › la falta de conexión muestra el mensaje y permite reintentar
- `macrofit_app/test/features/my_routines/presentation/recommended_routine_view_test.dart` › si no se pudo revisar la rutina permite reintentar

### <a id="caso-16"></a>Caso 16 · HU-15 — Ruta de la pantalla

Mobile: 3 · Backend: 0

**Mobile**

- `macrofit_app/test/app/router_test.dart` › rutinas del usuario (HU-16) › un usuario con perfil abre la rutina recomendada (HU-15)
- `macrofit_app/test/app/router_test.dart` › rutinas del usuario (HU-16) › un coach, un usuario sin perfil o sin sesión no abren la recomendada
- `macrofit_app/test/app/app_test.dart` › rutina recomendada (HU-15) › /user/routines/recommended no se confunde con un detalle
