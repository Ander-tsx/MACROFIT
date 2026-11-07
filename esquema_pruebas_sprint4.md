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

## Cómo se cuentan las pruebas

- **Mobile**: cada `test` o `testWidgets` de `macrofit_app/test/` (Flutter).
- **Backend**: cada prueba unitaria `#[test]` de `backend/src/` (Rust) más cada request de la colección de Postman (`backend/postman/`), que verifica el código de estado y la estructura de la respuesta. Los requests de "Preparación" (crear cuentas o iniciar sesión para los siguientes) no se cuentan.
- Una misma prueba puede contar en más de un caso cuando verifica varios criterios (p. ej. las pruebas generales de TEC-14 cuentan para cada endpoint nuevo del catálogo de `routes/openapi.rs`).
- No se cuentan las pruebas manuales de punta a punta ni las capturas de evidencia.

Inventario al cerrar HU-15-API: **589** pruebas mobile (`flutter test`, sin cambios), **278** pruebas de Rust (`cargo test`: 250 se ejecutan y 28 requieren MongoDB y se ejecutan con `--ignored`) y **252** requests de Postman en la colección combinada (sin contar los 102 de preparación). HU-15-API agrega 10 pruebas de Rust (6 puras y 3 con MongoDB en `services/recommended_routines.rs`, y 1 de la respuesta en `routes/recommended_routines.rs`), amplía la de códigos de error de `error.rs` con `EXERCISE_CATALOG_INCOMPLETE` y agrega el módulo de Postman `recommended_routines` con 7 requests (más 13 de preparación). La colección completa pasó dos veces seguidas con Newman contra una base temporal (358 requests y 979 aserciones por corrida, 0 fallos).
Inventario al cerrar HU-16-API: **633** pruebas mobile (`flutter test`; sin cambios de esta historia, 589 antes de HU-16-APP y HU-17-APP), **301** pruebas de Rust (`cargo test`: 270 se ejecutan y 31 requieren MongoDB y se ejecutan con `--ignored`; 291 en `develop` con HU-15-API y HU-17-API) y **293** requests de Postman en la colección combinada (sin contar los 133 de preparación). HU-16-API agrega 10 pruebas de Rust (5 puras y 3 con MongoDB en `services/user_routines.rs`, y 2 de las respuestas en `routes/user_routines.rs`) y el módulo de Postman `user_routines` con 16 requests (más 15 de preparación). La colección completa pasó dos veces seguidas con Newman contra una base temporal (430 requests y 1126 aserciones por corrida, 0 fallos).

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
