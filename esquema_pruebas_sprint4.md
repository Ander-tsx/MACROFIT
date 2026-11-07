## Casos de prueba

| Historia de usuario | ¿Qué comprueba? | Tipo | Criterio de aprobación | Pruebas realizadas |
|---|---|---|---|---|
| HU-15 | La rutina recomendada se genera con el objetivo, el nivel y los días del perfil y se guarda con origen `system` (RF-14, RN-08). | Unitaria | El motor recibe objetivo, nivel y días del perfil; la rutina guardada conserva nombre, sesiones numeradas y ejercicios con series, repeticiones y descanso, con `origin: system` y vigente; la respuesta no expone `user_id` ni `status`. | [**3**](#caso-01) (mobile 0 · backend 3) |
| HU-15 | Una sesión por día de entrenamiento, con las 3 divisiones y los 3 niveles del catálogo de TEC-09 (RF-14). | Unitaria | Principiante con 3 días: 3 sesiones de cuerpo completo con 2 series; intermedio con 4: torso y pierna alternados con 3 series; avanzado con 6: empuje, tirón y pierna con 4 series; sesiones numeradas desde 1, nunca más que los días, y solo ejercicios del nivel del usuario o inferiores. | [**5**](#caso-02) (mobile 0 · backend 5) |
| HU-15 | Pedir la rutina otra vez reemplaza la vigente sin borrar la anterior. | Integración | Regenerar devuelve `201` con otro `id`; la anterior queda como `replaced` con su fecha y sus sesiones intactas, hay una sola vigente por usuario y no se toca la rutina de otro usuario. | [**2**](#caso-03) (mobile 0 · backend 2) |
| HU-15 | Errores al generar la rutina. | Integración | Sin perfil responde `404 PROFILE_NOT_FOUND`; un catálogo sin ejercicios elegibles responde `503 EXERCISE_CATALOG_INCOMPLETE` sin perder la rutina vigente; días inválidos son `INTERNAL_ERROR`; una cuenta de coach responde `403 FORBIDDEN_ROLE` y sin sesión `401 UNAUTHORIZED`. | [**8**](#caso-04) (mobile 0 · backend 8) |
| HU-15 | `POST /users/me/routines/recommended` está en el contrato OpenAPI (TEC-14). | Unitaria | La especificación incluye el endpoint con seguridad `bearer_auth` de rol `user` y documenta `201`, `401`, `403`, `404` y `503`, con el cuerpo de la respuesta exitosa. | [**4**](#caso-05) (mobile 0 · backend 4) |

## Cómo se cuentan las pruebas

- **Mobile**: cada `test` o `testWidgets` de `macrofit_app/test/` (Flutter).
- **Backend**: cada prueba unitaria `#[test]` de `backend/src/` (Rust) más cada request de la colección de Postman (`backend/postman/`), que verifica el código de estado y la estructura de la respuesta. Los requests de "Preparación" (crear cuentas o iniciar sesión para los siguientes) no se cuentan.
- Una misma prueba puede contar en más de un caso cuando verifica varios criterios (p. ej. las pruebas generales de TEC-14 cuentan para cada endpoint nuevo del catálogo de `routes/openapi.rs`).
- No se cuentan las pruebas manuales de punta a punta ni las capturas de evidencia.

Inventario al cerrar HU-15-API: **589** pruebas mobile (`flutter test`, sin cambios), **278** pruebas de Rust (`cargo test`: 250 se ejecutan y 28 requieren MongoDB y se ejecutan con `--ignored`) y **252** requests de Postman en la colección combinada (sin contar los 102 de preparación). HU-15-API agrega 10 pruebas de Rust (6 puras y 3 con MongoDB en `services/recommended_routines.rs`, y 1 de la respuesta en `routes/recommended_routines.rs`), amplía la de códigos de error de `error.rs` con `EXERCISE_CATALOG_INCOMPLETE` y agrega el módulo de Postman `recommended_routines` con 7 requests (más 13 de preparación). La colección completa pasó dos veces seguidas con Newman contra una base temporal (358 requests y 979 aserciones por corrida, 0 fallos).

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
