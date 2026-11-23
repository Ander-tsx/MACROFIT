## Casos de prueba

| Historia de usuario | ¿Qué comprueba? | Tipo | Criterio de aprobación | Pruebas realizadas |
|---|---|---|---|---|
| HU-15 | La rutina recomendada se genera con el objetivo, el nivel y los días del perfil y se guarda con origen `system` (RF-14, RN-08). | Unitaria | El motor recibe objetivo, nivel y días del perfil; la rutina guardada conserva nombre, sesiones numeradas y ejercicios con series, repeticiones y descanso, con `origin: system` y vigente; la respuesta no expone `user_id` ni `status`. | [**3**](#caso-01) (mobile 0 · backend 3) |
| HU-15 | Una sesión por día de entrenamiento, con las 3 divisiones y los 3 niveles del catálogo de TEC-09 (RF-14). | Unitaria | Principiante con 3 días: 3 sesiones de cuerpo completo con 2 series; intermedio con 4: torso y pierna alternados con 3 series; avanzado con 6: empuje, tirón y pierna con 4 series; sesiones numeradas desde 1, nunca más que los días, y solo ejercicios del nivel del usuario o inferiores. | [**5**](#caso-02) (mobile 0 · backend 5) |
| HU-15 | Pedir la rutina otra vez reemplaza la vigente sin borrar la anterior. | Integración | Regenerar devuelve `201` con otro `id`; la anterior queda como `replaced` con su fecha y sus sesiones intactas, hay una sola vigente por usuario y no se toca la rutina de otro usuario. | [**2**](#caso-03) (mobile 0 · backend 2) |
| HU-15 | Errores al generar la rutina. | Integración | Sin perfil responde `404 PROFILE_NOT_FOUND`; un catálogo sin ejercicios elegibles responde `503 EXERCISE_CATALOG_INCOMPLETE` sin perder la rutina vigente; días inválidos son `INTERNAL_ERROR`; una cuenta de coach responde `403 FORBIDDEN_ROLE` y sin sesión `401 UNAUTHORIZED`. | [**8**](#caso-04) (mobile 0 · backend 8) |
| HU-15 | `POST /users/me/routines/recommended` está en el contrato OpenAPI (TEC-14). | Unitaria | La especificación incluye el endpoint con seguridad `bearer_auth` de rol `user` y documenta `201`, `401`, `403`, `404` y `503`, con el cuerpo de la respuesta exitosa. | [**4**](#caso-05) (mobile 0 · backend 4) |
| HU-16 | `GET /users/me/routines` lista la recomendada vigente y las asignadas activas, cada una con su origen (RN-08). | Integración | Primero la recomendada (`origin: system`, `coach_name: null`, `session_count` = días) y después las asignadas (`origin: coach`, nombre del coach, `session_count: 1`), la asignada más recientemente primero; sin rutinas responde `[]` y otro usuario no ve las rutinas ajenas. | [**8**](#caso-06) (mobile 0 · backend 8) |
| HU-16 | Una rutina asignada aparece en cuanto se crea la asignación y deja de aparecer al retirarse o al desvincularse (RF-23, RN-04). | Integración | La lista se consulta sin caché: la asignación nueva aparece en la siguiente consulta; una rutina eliminada (asignación retirada), una que ya no existe o una de un coach del que el usuario se desvinculó no aparece. | [**4**](#caso-07) (mobile 0 · backend 4) |
| HU-16 | `GET /routines/{id}` devuelve el detalle con la forma común de los dos orígenes (RF-15). | Unitaria | La recomendada conserva sus sesiones numeradas (`Día 1 · Cuerpo completo`); la del coach es una sola sesión, la 1, con el nombre de la rutina y todos sus ejercicios; cada ejercicio trae id, nombre, grupo muscular, series, repeticiones y descanso. | [**5**](#caso-08) (mobile 0 · backend 5) |
| HU-16 | Una rutina no accesible responde `404 ROUTINE_NOT_FOUND`. | Integración | Rutina de otro usuario (recomendada o asignada), retirada, recomendada reemplazada al regenerar, de un coach desvinculado, inexistente o con id mal formado. | [**7**](#caso-09) (mobile 0 · backend 7) |
| HU-16 | Roles, sesión y contrato OpenAPI (TEC-14). | Integración | Una cuenta de coach recibe `403 FORBIDDEN_ROLE` en la lista y en el detalle; sin sesión, `401 UNAUTHORIZED`; los dos endpoints están en la especificación con rol `user` y sus códigos. | [**7**](#caso-10) (mobile 0 · backend 7) |
| HU-15 | La app interpreta `POST /users/me/routines/recommended`. | Unitaria | La respuesta `201` da nombre, objetivo, nivel, días y sesiones numeradas con ejercicios, series, repeticiones y descanso; `404 PROFILE_NOT_FOUND` y `503 EXERCISE_CATALOG_INCOMPLETE` salen como `ApiException`. | [**4**](#caso-11) (mobile 4 · backend 0) |
| HU-15 | Solicitar la rutina desde la pantalla principal con estado de carga (RF-14). | Interfaz | La tarjeta **Rutina recomendada** del inicio abre la pantalla; abrirla no genera; mientras se genera se muestra la carga y el botón no envía dos veces. | [**7**](#caso-12) (mobile 7 · backend 0) |
| HU-15 | La rutina se muestra completa (RF-14, RF-15). | Interfaz | Se ven nombre, objetivo, nivel y días, y cada sesión numerada con sus ejercicios, series, repeticiones y descanso. | [**1**](#caso-13) (mobile 1 · backend 0) |
| HU-15 | Generarla de nuevo pide confirmación. | Interfaz | Con una rutina generada o vigente, **Generar de nuevo** pide confirmar porque reemplaza la anterior; cancelar no genera; al confirmar se muestra la nueva; si falla se conserva la que se veía. | [**6**](#caso-14) (mobile 6 · backend 0) |
| HU-15 | Errores sin cerrar la app (RNF-11). | Interfaz | `404 PROFILE_NOT_FOUND` muestra un mensaje que lleva a completar el perfil; el catálogo incompleto y la falta de conexión muestran el mensaje en español y permiten reintentar; si no se pudo revisar la rutina vigente no se ofrece generar. | [**8**](#caso-15) (mobile 8 · backend 0) |
| HU-15 | Ruta de la pantalla. | Unitaria | Solo un usuario con perfil abre `/user/routines/recommended` (un coach, un usuario sin perfil o sin sesión son redirigidos) y no se confunde con el detalle de una rutina. | [**3**](#caso-16) (mobile 3 · backend 0) |
| HU-22 | Validación del periodo (`from` y `to`). | Unitaria | Fechas ausentes, vacías o con formato inválido, `from` posterior a `to` o más de 93 días responden 400 `VALIDATION_ERROR` con un solo campo señalado, en el progreso propio y en el del cliente. | [**10**](#caso-17) (mobile 0 · backend 10) |
| HU-22 | Series de peso y consumo del periodo (RF-17, RF-18). | Integración | `GET /users/me/progress` devuelve un día por fecha del periodo con meta, consumo y restante, y los pesos registrados del primer al último día en hora de México (`APP_UTC_OFFSET`), en semana (7 días) y en mes (30 días). | [**3**](#caso-18) (mobile 0 · backend 3) |
| HU-22 | Cumplimiento semanal de rutinas (RF-16, RF-18). | Unitaria | Bloques de 7 días desde `from` (el último puede ser más corto) con los días de entrenamiento del perfil y las sesiones completadas de ese bloque; no cuentan las de otro usuario ni las de fuera del periodo. | [**5**](#caso-19) (mobile 0 · backend 5) |
| HU-22 | Restricción del progreso por sesión y rol. | Integración | Sin sesión responde 401 `UNAUTHORIZED`; una cuenta de coach en `/users/me/progress` y una de usuario en `/coach/clients/{clientId}/progress` responden 403 `FORBIDDEN_ROLE`. | [**3**](#caso-20) (mobile 0 · backend 3) |
| HU-23 | El coach ve el mismo progreso que su cliente (RF-25). | Integración | Con vinculación activa, `GET /coach/clients/{clientId}/progress` devuelve exactamente lo mismo que `GET /users/me/progress` del cliente para el mismo periodo, incluidas las sesiones completadas. | [**2**](#caso-21) (mobile 0 · backend 2) |
| HU-23 | Solo un coach vinculado ve el progreso (RN-04). | Integración | Un coach no vinculado, un id mal formado y el coach después de que el cliente se desvincula reciben 403 `CLIENT_NOT_LINKED`. | [**3**](#caso-22) (mobile 0 · backend 3) |
| HU-21 | Registro de peso en la app (RF-17). | Unitaria | El peso vacío, no numérico o fuera de 35–250 kg se rechaza antes de llamar a la API y se conserva en el campo; uno válido se registra, aparece al inicio del historial y deja el campo vacío para el siguiente; los errores de red y de validación de la API se muestran; **Registrar** abre el registro desde Progreso. | [**14**](#caso-23) (mobile 14 · backend 0) |
| HU-22 | Gráficas de progreso por semana y por mes (RF-18). | Interfaz | Se muestran peso, consumo por día y entrenamiento; se cambia entre semana (7 días hasta hoy) y mes (del día 1 a hoy) sin pasar a un periodo futuro; un periodo sin datos muestra mensajes en lugar de gráficas; sin conexión se puede reintentar. | [**25**](#caso-24) (mobile 25 · backend 0) |
| HU-23 | Progreso de un cliente para el coach (RF-25, RN-04). | Interfaz | Desde el detalle del cliente se abre su progreso semanal o mensual, de solo lectura (sin **Registrar**); un periodo sin datos lo indica; `CLIENT_NOT_LINKED` marca al cliente como desvinculado y regresa a la lista; sin conexión se puede reintentar. | [**18**](#caso-25) (mobile 18 · backend 0) |

## Cómo se cuentan las pruebas

- **Mobile**: cada `test` o `testWidgets` de `macrofit_app/test/` (Flutter).
- **Backend**: cada prueba unitaria `#[test]` de `backend/src/` (Rust) más cada request de la colección de Postman (`backend/postman/`), que verifica el código de estado y la estructura de la respuesta. Los requests de "Preparación" (crear cuentas o iniciar sesión para los siguientes) no se cuentan.
- Una misma prueba puede contar en más de un caso cuando verifica varios criterios (p. ej. las pruebas generales de TEC-14 cuentan para cada endpoint nuevo del catálogo de `routes/openapi.rs`).
- No se cuentan las pruebas manuales de punta a punta ni las capturas de evidencia.

Inventario al cerrar HU-15-API: **589** pruebas mobile (`flutter test`, sin cambios), **278** pruebas de Rust (`cargo test`: 250 se ejecutan y 28 requieren MongoDB y se ejecutan con `--ignored`) y **252** requests de Postman en la colección combinada (sin contar los 102 de preparación). HU-15-API agrega 10 pruebas de Rust (6 puras y 3 con MongoDB en `services/recommended_routines.rs`, y 1 de la respuesta en `routes/recommended_routines.rs`), amplía la de códigos de error de `error.rs` con `EXERCISE_CATALOG_INCOMPLETE` y agrega el módulo de Postman `recommended_routines` con 7 requests (más 13 de preparación). La colección completa pasó dos veces seguidas con Newman contra una base temporal (358 requests y 979 aserciones por corrida, 0 fallos).
Inventario al cerrar HU-16-API: **633** pruebas mobile (`flutter test`; sin cambios de esta historia, 589 antes de HU-16-APP y HU-17-APP), **301** pruebas de Rust (`cargo test`: 270 se ejecutan y 31 requieren MongoDB y se ejecutan con `--ignored`; 291 en `develop` con HU-15-API y HU-17-API) y **293** requests de Postman en la colección combinada (sin contar los 133 de preparación). HU-16-API agrega 10 pruebas de Rust (5 puras y 3 con MongoDB en `services/user_routines.rs`, y 2 de las respuestas en `routes/user_routines.rs`) y el módulo de Postman `user_routines` con 16 requests (más 15 de preparación). La colección completa pasó dos veces seguidas con Newman contra una base temporal (430 requests y 1126 aserciones por corrida, 0 fallos).

Inventario al cerrar HU-15-APP: **661** pruebas mobile (`flutter test`; 633 en `develop` con HU-16-APP y HU-17-APP). HU-15-APP agrega 28 (3 de datos, 12 del ViewModel, 9 de la pantalla, 2 de rutas y 2 de flujos en `app_test`) y mueve la tarjeta de sesión del detalle de HU-16 al widget compartido `SessionPlanCard`, sin cambiar sus pruebas. Sin cambios en el backend. La prueba de punta a punta en un dispositivo físico contra la API desplegada queda pendiente (no se cuenta).

Inventario al cerrar QA-08: **685** pruebas mobile (`flutter test`; 682 en `develop`), **319** pruebas de Rust (`cargo test`: 282 se ejecutan y 37 requieren MongoDB y se ejecutan con `--ignored`) y **332** requests de Postman en la colección combinada (sin contar los 162 de preparación). QA-08 agrega 3 pruebas de widgets del registro de peso, 6 pruebas de Rust (5 de `validate_range` y 1 con MongoDB de los pesos del primer y último día) y el módulo de Postman `progress` con 14 requests (más 12 de preparación), y documenta los casos 17 a 25 con las pruebas de HU-21-APP, HU-22 y HU-23 que ya existían. La colección completa pasó dos veces seguidas con Newman contra una base temporal (498 requests y 1272 aserciones por corrida, 0 fallos).

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

### <a id="caso-06"></a>Caso 06 · HU-16 — Lista con la recomendada y las asignadas con su origen (RN-08)

Mobile: 0 · Backend: 8

**Backend (Rust)**

- `backend/src/services/user_routines.rs` › `lista_la_recomendada_primero_y_despues_las_asignadas_mas_recientes`
- `backend/src/services/user_routines.rs` › `sin_rutinas_la_lista_esta_vacia_y_solo_con_recomendada_tiene_una`
- `backend/src/services/user_routines.rs` › `mongo::lista_y_detalle_de_recomendada_y_asignada` (requiere MongoDB, `--ignored`)
- `backend/src/routes/user_routines.rs` › `la_lista_trae_origen_y_coach_name_nulo_en_la_recomendada`

**Backend (Postman)**

- Postman › HU-16 Rutinas del usuario › 01 - Lista vacía: usuario sin rutinas
- Postman › HU-16 Rutinas del usuario › 02 - Lista solo con la recomendada
- Postman › HU-16 Rutinas del usuario › 03 - Lista con la recomendada y la asignada
- Postman › HU-16 Rutinas del usuario › 08 - El otro usuario no ve las rutinas de Ana

### <a id="caso-07"></a>Caso 07 · HU-16 — La asignada aparece al crearse y desaparece al retirarse (RF-23, RN-04)

Mobile: 0 · Backend: 4

HU-20-API (retirar una asignación) aún no está en `develop`: la retirada se prueba eliminando la rutina, que retira sus
asignaciones (HU-18/HU-19). La consulta solo lee asignaciones `active`, así que una retirada por HU-20 tampoco aparece.

**Backend (Rust)**

- `backend/src/services/user_routines.rs` › `omite_asignaciones_de_un_coach_no_vinculado_o_de_rutinas_que_ya_no_existen`
- `backend/src/services/user_routines.rs` › `mongo::al_desvincularse_las_asignadas_dejan_de_aparecer` (requiere MongoDB, `--ignored`)

**Backend (Postman)**

- Postman › HU-16 Rutinas del usuario › 03 - Lista con la recomendada y la asignada
- Postman › HU-16 Rutinas del usuario › 14 - La rutina retirada deja de aparecer

### <a id="caso-08"></a>Caso 08 · HU-16 — Detalle con la forma común de los dos orígenes (RF-15)

Mobile: 0 · Backend: 5

**Backend (Rust)**

- `backend/src/services/user_routines.rs` › `detalle_de_la_recomendada_conserva_sus_sesiones_numeradas`
- `backend/src/services/user_routines.rs` › `detalle_del_coach_es_una_sola_sesion_con_todos_sus_ejercicios`
- `backend/src/routes/user_routines.rs` › `el_detalle_tiene_la_forma_comun_de_los_dos_origenes`

**Backend (Postman)**

- Postman › HU-16 Rutinas del usuario › 04 - Detalle de la recomendada
- Postman › HU-16 Rutinas del usuario › 05 - Detalle de la asignada

### <a id="caso-09"></a>Caso 09 · HU-16 — Rutina no accesible: `404 ROUTINE_NOT_FOUND`

Mobile: 0 · Backend: 7

**Backend (Rust)**

- `backend/src/services/user_routines.rs` › `mongo::rutinas_ajenas_retiradas_reemplazadas_o_mal_formadas_responden_404` (requiere MongoDB, `--ignored`)

**Backend (Postman)**

- Postman › HU-16 Rutinas del usuario › 06 - Rutina de otro usuario: 404 ROUTINE_NOT_FOUND
- Postman › HU-16 Rutinas del usuario › 07 - Rutina asignada a otro usuario: 404 ROUTINE_NOT_FOUND
- Postman › HU-16 Rutinas del usuario › 09 - Id mal formado: 404 ROUTINE_NOT_FOUND
- Postman › HU-16 Rutinas del usuario › 10 - Rutina inexistente: 404 ROUTINE_NOT_FOUND
- Postman › HU-16 Rutinas del usuario › 15 - Detalle de la rutina retirada: 404 ROUTINE_NOT_FOUND
- Postman › HU-16 Rutinas del usuario › 16 - Detalle de una recomendada reemplazada: 404 ROUTINE_NOT_FOUND

### <a id="caso-10"></a>Caso 10 · HU-16 — Roles, sesión y contrato OpenAPI (TEC-14)

Mobile: 0 · Backend: 7

**Backend (Rust)**

- `backend/src/routes/openapi.rs` › `la_especificacion_incluye_todos_los_endpoints_del_catalogo`
- `backend/src/routes/openapi.rs` › `cada_operacion_documenta_sus_codigos_de_estado`
- `backend/src/routes/openapi.rs` › `cada_respuesta_exitosa_documenta_su_cuerpo`
- `backend/src/routes/openapi.rs` › `rutas_protegidas_declaran_bearer_y_rol`

**Backend (Postman)**

- Postman › HU-16 Rutinas del usuario › 11 - Cuenta de coach (lista): 403 FORBIDDEN_ROLE
- Postman › HU-16 Rutinas del usuario › 12 - Cuenta de coach (detalle): 403 FORBIDDEN_ROLE
- Postman › HU-16 Rutinas del usuario › 13 - Sin sesión: 401 UNAUTHORIZED

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

### <a id="caso-17"></a>Caso 17 · HU-22 — Validación del periodo (`from` y `to`)

Mobile: 0 · Backend: 10

**Backend (Rust)**

- `backend/src/services/progress.rs` › `el_rango_valido_devuelve_las_dos_fechas`
- `backend/src/services/progress.rs` › `las_fechas_ausentes_o_vacias_se_senalan`
- `backend/src/services/progress.rs` › `las_fechas_con_formato_invalido_se_senalan`
- `backend/src/services/progress.rs` › `el_inicio_posterior_al_fin_se_rechaza`
- `backend/src/services/progress.rs` › `el_rango_admite_93_dias_y_no_mas`

**Backend (Postman)**

- Postman › HU-22 HU-23 Progreso › 03 - Sin fechas
- Postman › HU-22 HU-23 Progreso › 04 - Fecha con formato inválido
- Postman › HU-22 HU-23 Progreso › 05 - Inicio posterior al fin
- Postman › HU-22 HU-23 Progreso › 06 - Rango de más de 93 días
- Postman › HU-22 HU-23 Progreso › 12 - Fechas inválidas en el progreso del cliente


### <a id="caso-18"></a>Caso 18 · HU-22 — Series de peso y consumo del periodo (RF-17, RF-18)

Mobile: 0 · Backend: 3

Hallazgo de QA-08: los pesos del primer día del periodo no aparecían porque el filtro empezaba al final de ese día (`end_of_day`); ahora empieza a las 00:00 de México (`start_of_day`).

**Backend (Rust)**

- `backend/src/services/progress.rs` › `los_pesos_del_primer_y_ultimo_dia_del_rango_se_incluyen` (requiere MongoDB)

**Backend (Postman)**

- Postman › HU-22 HU-23 Progreso › 07 - Progreso de la semana
- Postman › HU-22 HU-23 Progreso › 08 - Progreso del mes


### <a id="caso-19"></a>Caso 19 · HU-22 — Cumplimiento semanal de rutinas (RF-16, RF-18)

Mobile: 0 · Backend: 5

**Backend (Rust)**

- `backend/src/services/progress.rs` › `el_cumplimiento_cuenta_las_sesiones_completadas_de_cada_semana`
- `backend/src/services/progress.rs` › `la_ultima_semana_parcial_tambien_cuenta_y_las_fechas_fuera_del_rango_no`
- `backend/src/services/progress.rs` › `sin_sesiones_completadas_el_cumplimiento_es_cero`
- `backend/src/services/progress.rs` › `el_progreso_cuenta_las_sesiones_completadas_del_usuario_en_el_rango` (requiere MongoDB)

**Backend (Postman)**

- Postman › HU-17 Sesiones completadas › 24 - El progreso de Ana cuenta sus sesiones completadas (HU-22)


### <a id="caso-20"></a>Caso 20 · HU-22 — Restricción del progreso por sesión y rol

Mobile: 0 · Backend: 3

**Backend (Postman)**

- Postman › HU-22 HU-23 Progreso › 01 - Sin sesión
- Postman › HU-22 HU-23 Progreso › 02 - Progreso propio con una cuenta de coach
- Postman › HU-22 HU-23 Progreso › 09 - Progreso de un cliente con una cuenta de usuario


### <a id="caso-21"></a>Caso 21 · HU-23 — El coach ve el mismo progreso que su cliente (RF-25)

Mobile: 0 · Backend: 2

**Backend (Postman)**

- Postman › HU-22 HU-23 Progreso › 13 - El coach vinculado ve el mismo progreso que Lía (RF-25)
- Postman › HU-17 Sesiones completadas › 25 - El coach ve las mismas sesiones en el progreso de Ana (HU-23)


### <a id="caso-22"></a>Caso 22 · HU-23 — Solo un coach vinculado ve el progreso (RN-04)

Mobile: 0 · Backend: 3

**Backend (Postman)**

- Postman › HU-22 HU-23 Progreso › 10 - Coach no vinculado
- Postman › HU-22 HU-23 Progreso › 11 - Id de cliente mal formado
- Postman › HU-22 HU-23 Progreso › 14 - Tras la desvinculación el coach ya no ve el progreso (RN-04)


### <a id="caso-23"></a>Caso 23 · HU-21 — Registro de peso en la app (RF-17)

Mobile: 14 · Backend: 0

Hallazgo de QA-08: después de registrar, el campo seguía mostrando el peso pero el ViewModel ya lo había vaciado, así que volver a tocar **Registrar peso** decía que estaba vacío. Ahora el campo se vacía al registrar.

**Mobile**

- `macrofit_app/test/features/progress/presentation/weights_view_model_test.dart` › ProfileValidators weight (HU-21 / TEC-12) › rechaza vacío o no numérico
- `macrofit_app/test/features/progress/presentation/weights_view_model_test.dart` › ProfileValidators weight (HU-21 / TEC-12) › rechaza fuera de rango (35 a 250 kg) y acepta coma decimal
- `macrofit_app/test/features/progress/presentation/weights_view_model_test.dart` › WeightModel.fromJson › convierte JSON correctamente y parsea recorded_at
- `macrofit_app/test/features/progress/presentation/weights_view_model_test.dart` › WeightsRemoteDataSource & WeightsRepositoryImpl con FakeHttpAdapter › getWeights y createWeight se comunican correctamente con la API
- `macrofit_app/test/features/progress/presentation/weights_view_model_test.dart` › WeightsViewModel › carga el historial de peso exitosamente
- `macrofit_app/test/features/progress/presentation/weights_view_model_test.dart` › WeightsViewModel › maneja error al cargar el historial y permite reintentar
- `macrofit_app/test/features/progress/presentation/weights_view_model_test.dart` › WeightsViewModel › registra un peso válido y lo añade al inicio del historial
- `macrofit_app/test/features/progress/presentation/weights_view_model_test.dart` › WeightsViewModel › maneja error de red (sin conexión) al registrar
- `macrofit_app/test/features/progress/presentation/weights_view_model_test.dart` › WeightsViewModel › valida localmente peso inválido antes de llamar a la API
- `macrofit_app/test/features/progress/presentation/weights_view_model_test.dart` › WeightsViewModel › maneja error de validación 400 de la API
- `macrofit_app/test/app/app_test.dart` › progreso (HU-22) › "Registrar" abre el registro de peso
- `macrofit_app/test/features/progress/presentation/weights_view_test.dart` › al registrar un peso el campo queda vacío
- `macrofit_app/test/features/progress/presentation/weights_view_test.dart` › se puede registrar otro peso justo después del primero
- `macrofit_app/test/features/progress/presentation/weights_view_test.dart` › un peso inválido se conserva en el campo con su mensaje


### <a id="caso-24"></a>Caso 24 · HU-22 — Gráficas de progreso por semana y por mes (RF-18)

Mobile: 25 · Backend: 0

**Mobile**

- `macrofit_app/test/features/progress/data/progress_repository_impl_test.dart` › pide el periodo y convierte pesos, días y cumplimiento
- `macrofit_app/test/features/progress/data/progress_repository_impl_test.dart` › un periodo sin datos llega con listas vacías y sin gráficas
- `macrofit_app/test/features/progress/data/progress_repository_impl_test.dart` › un error de la API llega como ApiException con su código
- `macrofit_app/test/features/progress/data/progress_repository_impl_test.dart` › contrato real (`ProgressResponse` del backend) › HU-22: convierte `daily`, la meta en `totals` y `compliance`
- `macrofit_app/test/features/progress/domain/progress_period_test.dart` › semana › la actual son los 7 días que terminan hoy
- `macrofit_app/test/features/progress/domain/progress_period_test.dart` › semana › anterior y siguiente se mueven 7 días sin pasar de hoy
- `macrofit_app/test/features/progress/domain/progress_period_test.dart` › semana › no se puede ir a un periodo futuro
- `macrofit_app/test/features/progress/domain/progress_period_test.dart` › mes › el actual va del día 1 a hoy
- `macrofit_app/test/features/progress/domain/progress_period_test.dart` › mes › el anterior es el mes completo, también en febrero
- `macrofit_app/test/features/progress/domain/progress_period_test.dart` › mes › el siguiente de un mes pasado llega hasta hoy si es el actual
- `macrofit_app/test/features/progress/domain/progress_period_test.dart` › mes › cambia de año
- `macrofit_app/test/features/progress/presentation/progress_view_model_test.dart` › empieza en la semana que termina hoy y la carga
- `macrofit_app/test/features/progress/presentation/progress_view_model_test.dart` › cambia a mes: del día 1 hasta hoy
- `macrofit_app/test/features/progress/presentation/progress_view_model_test.dart` › va al periodo anterior y regresa, sin pasar de hoy
- `macrofit_app/test/features/progress/presentation/progress_view_model_test.dart` › en mes, el anterior es octubre completo
- `macrofit_app/test/features/progress/presentation/progress_view_model_test.dart` › un periodo sin datos no tiene gráficas que mostrar
- `macrofit_app/test/features/progress/presentation/progress_view_model_test.dart` › sin conexión guarda el mensaje y al reintentar lo limpia
- `macrofit_app/test/features/progress/presentation/progress_view_model_test.dart` › si falla una recarga conserva el último reporte
- `macrofit_app/test/features/progress/presentation/progress_view_model_test.dart` › descarta la respuesta de un periodo que ya no se ve
- `macrofit_app/test/features/progress/presentation/progress_view_model_test.dart` › elige el macro de la gráfica de consumo
- `macrofit_app/test/app/app_test.dart` › progreso (HU-22) › muestra peso, consumo por día y entrenamiento de la semana
- `macrofit_app/test/app/app_test.dart` › progreso (HU-22) › cambia el macro de la gráfica de consumo
- `macrofit_app/test/app/app_test.dart` › progreso (HU-22) › cambia a mes y no permite ir a un periodo futuro
- `macrofit_app/test/app/app_test.dart` › progreso (HU-22) › sin datos suficientes muestra mensajes en lugar de gráficas
- `macrofit_app/test/app/app_test.dart` › progreso (HU-22) › sin conexión muestra el error en español y reintenta


### <a id="caso-25"></a>Caso 25 · HU-23 — Progreso de un cliente para el coach (RF-25, RN-04)

Mobile: 18 · Backend: 0

**Mobile**

- `macrofit_app/test/features/progress/data/progress_repository_impl_test.dart` › HU-23: pide el progreso del cliente con el periodo
- `macrofit_app/test/features/progress/data/progress_repository_impl_test.dart` › HU-23: `403 CLIENT_NOT_LINKED` llega como ApiException
- `macrofit_app/test/features/clients/presentation/client_progress_view_model_test.dart` › carga la semana que termina hoy del cliente elegido
- `macrofit_app/test/features/clients/presentation/client_progress_view_model_test.dart` › un periodo sin datos no tiene gráficas y no es un error
- `macrofit_app/test/features/clients/presentation/client_progress_view_model_test.dart` › cambia a mes (del día 1 a hoy) y vuelve a semana
- `macrofit_app/test/features/clients/presentation/client_progress_view_model_test.dart` › elegir el mismo periodo no vuelve a pedirlo
- `macrofit_app/test/features/clients/presentation/client_progress_view_model_test.dart` › navega a periodos anteriores y no pasa de hoy
- `macrofit_app/test/features/clients/presentation/client_progress_view_model_test.dart` › CLIENT_NOT_LINKED marca al cliente como desvinculado (RN-04)
- `macrofit_app/test/features/clients/presentation/client_progress_view_model_test.dart` › sin conexión muestra el mensaje y al reintentar carga
- `macrofit_app/test/features/clients/presentation/client_progress_view_model_test.dart` › si falla una recarga conserva el último reporte
- `macrofit_app/test/features/clients/presentation/client_progress_view_model_test.dart` › descarta la respuesta de un periodo que ya no se ve
- `macrofit_app/test/features/clients/presentation/client_progress_view_model_test.dart` › elige el macro de la gráfica de consumo
- `macrofit_app/test/app/app_test.dart` › progreso de un cliente (HU-23) › desde el detalle se abre el progreso semanal del cliente
- `macrofit_app/test/app/app_test.dart` › progreso de un cliente (HU-23) › es de solo lectura: sin botón para registrar peso
- `macrofit_app/test/app/app_test.dart` › progreso de un cliente (HU-23) › cambia a mes
- `macrofit_app/test/app/app_test.dart` › progreso de un cliente (HU-23) › un periodo sin datos lo indica con textos para el coach
- `macrofit_app/test/app/app_test.dart` › progreso de un cliente (HU-23) › un cliente desvinculado lo indica y regresa a la lista
- `macrofit_app/test/app/app_test.dart` › progreso de un cliente (HU-23) › sin conexión muestra el error y permite reintentar
