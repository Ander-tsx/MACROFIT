## Casos de prueba

| Historia de usuario | ¿Qué comprueba? | Tipo | Criterio de aprobación | Pruebas realizadas |
|---|---|---|---|---|
| TEC-12 | Rangos válidos del perfil confirmados (peso 35–250 kg, estatura 130–230 cm, edad 18–80 años). | Unitaria | Los límites se aceptan; un valor justo fuera de cada límite se rechaza en su campo con `VALIDATION_ERROR`. | [**6**](#caso-01) (mobile 0 · backend 6) |
| TEC-12 | Rango de peso reutilizable para el registro de peso (HU-21). | Unitaria | `parse_weight_kg` acepta 35 y 250 kg y rechaza lo que queda fuera con el mismo mensaje que el perfil. | [**1**](#caso-02) (mobile 0 · backend 1) |
| TEC-12 | Cálculo de calorías con la fórmula confirmada. | Unitaria | Para al menos 3 perfiles de referencia, el resultado coincide con el cálculo manual de Mifflin-St Jeor (± 1). | [**6**](#caso-03) (mobile 0 · backend 6) |
| TEC-12 | Distribución de proteína y grasa confirmada para cada objetivo. | Unitaria | Para bajar grasa, mantener y ganar músculo, la proteína es 2.0, 1.6 y 1.8 g/kg y la grasa el 25 % de las calorías. | [**6**](#caso-04) (mobile 0 · backend 6) |
| TEC-12 | Mínimo de calorías de la meta calculada. | Integración | Un cálculo bajo el mínimo sube a 1 200 kcal (mujer) o 1 500 kcal (hombre), con la grasa calculada sobre ese mínimo; en los límites del perfil la meta queda entre el mínimo y 10 000 kcal. | [**5**](#caso-05) (mobile 0 · backend 5) |
| HU-21 | Registro de un peso válido. | Integración | `POST /users/me/weights` con un peso dentro del rango de TEC-12 responde 201 con el peso, el usuario de la sesión y la fecha del servidor. | [**4**](#caso-06) (mobile 0 · backend 4) |
| HU-21 | Validación del peso. | Unitaria | Un peso ausente, nulo, no numérico o fuera de 35–250 kg responde 400 `VALIDATION_ERROR` en `weight_kg`, con el mismo rango y mensaje que el perfil. | [**7**](#caso-07) (mobile 0 · backend 7) |
| HU-21 | Historial de peso del usuario. | Integración | `GET /users/me/weights` devuelve solo los pesos del usuario de la sesión, del más reciente al más antiguo, iguales a los enviados. | [**2**](#caso-08) (mobile 0 · backend 2) |
| HU-21 | Restricción por sesión y rol. | Integración | Sin sesión responde 401 `UNAUTHORIZED`; una cuenta de coach responde 403 `FORBIDDEN_ROLE` al registrar y al consultar. | [**3**](#caso-09) (mobile 0 · backend 3) |
| HU-21 | El último peso actualiza el perfil y la meta. | Integración | Tras registrar un peso, `weight_kg` del perfil es ese peso y la meta calculada se recalcula con él. | [**2**](#caso-10) (mobile 0 · backend 2) |
| TEC-14 | La especificación OpenAPI se genera desde el código e incluye todos los endpoints del catálogo del README. | Unitaria | La especificación tiene exactamente los métodos y rutas del catálogo (Sprint 1 y HU-12), es OpenAPI 3.1 y su servidor es `/api/v1`. | [**2**](#caso-11) (mobile 0 · backend 2) |
| TEC-14 | Cada operación documentada existe en el router de la API. | Integración | Ninguna operación de la especificación responde 404 ni 405 al llamarla en el router real. | [**1**](#caso-12) (mobile 0 · backend 1) |
| TEC-14 | Cada endpoint documenta su cuerpo de petición, su respuesta y sus códigos de error. | Unitaria | Los códigos de estado documentados coinciden con los esperados de cada endpoint; cada respuesta exitosa tiene cuerpo (salvo 204) y solo los endpoints que reciben JSON documentan su petición. | [**3**](#caso-13) (mobile 0 · backend 3) |
| TEC-14 | Formato de error `{ "error": { code, message, fields } }` definido una sola vez. | Unitaria | Todas las respuestas 4xx referencian `ErrorResponse` y nombran sus códigos; lo que serializa `AppError` tiene exactamente esa forma, con `fields` siempre como objeto. | [**3**](#caso-14) (mobile 0 · backend 3) |
| TEC-14 | Esquema Bearer declarado y aplicado a las rutas protegidas con su rol. | Unitaria | `bearer_auth` es HTTP bearer JWT; cada ruta protegida lo exige con `[]` (cualquier sesión), `["user"]` o `["coach"]`, y las públicas no tienen seguridad. | [**2**](#caso-15) (mobile 0 · backend 2) |
| TEC-14 | Las rutas `/dev` solo aparecen con `APP_ENV=development`. | Integración | Sin desarrollo, `/dev/seed/coach-links` no está en la especificación y responde 404; con desarrollo está documentada y responde 400 a un cuerpo vacío. | [**3**](#caso-16) (mobile 0 · backend 3) |
| TEC-14 | La documentación se ve en una ruta registrada en el catálogo. | Integración | `/api/v1/openapi.json` responde la especificación en JSON y `/api/v1/docs/` la página HTML de Swagger UI. | [**2**](#caso-17) (mobile 0 · backend 2) |
| TEC-09 | Catálogo base con cantidad mínima acordada (18 ejercicios) y cobertura de todas las combinaciones de grupo muscular y nivel (RF-14). | Unitaria | Al menos 18 ejercicios registrados; cada combinación de los 6 grupos musculares y 3 niveles tiene al menos un ejercicio; nombres únicos y no vacíos. | [**5**](#caso-18) (mobile 0 · backend 5) |
| TEC-09 | Niveles de dificultad idénticos al perfil (beginner, intermediate, advanced) y grupos musculares esperados. | Unitaria | Los niveles de ejercicio coinciden con `Level` de `UserProfile`; los parsers aceptan valores válidos y rechazan inválidos. | [**3**](#caso-19) (mobile 0 · backend 3) |
| TEC-09 | Carga reproducible e idempotente sin duplicación de ejercicios. | Integración | Ejecutar `seed_exercises` repetidas veces mantiene exactamente 18 ejercicios en la colección `exercises` sin duplicados. | [**2**](#caso-20) (mobile 0 · backend 2) |
| TEC-09 | Consulta y filtrado del catálogo de ejercicios vía API REST. | Integración | `GET /api/v1/exercises` responde la lista completa; los parámetros de consulta `muscle_group` y `level` filtran correctamente; `POST /api/v1/dev/seed/exercises` realiza la siembra en desarrollo. | [**4**](#caso-21) (mobile 0 · backend 4) |
| HU-24 | La lista del coach solo incluye clientes con vínculo activo (RF-19, RN-04). | Integración | `GET /coach/clients` devuelve a los clientes vinculados y no a uno que se desvinculó (HU-14). | [**1**](#caso-22) (mobile 0 · backend 1) |
| HU-24 | Resumen de la meta vigente de cada cliente. | Integración | `goal` trae calorías, proteína, grasa y origen de la meta vigente (la del coach tiene prioridad y las futuras no cuentan); es `null` si el cliente no tiene metas. | [**5**](#caso-23) (mobile 0 · backend 5) |
| HU-24 | Fecha del último registro de comida de cada cliente. | Integración | `last_meal_at` es la fecha y hora (RFC 3339, UTC) del registro más reciente; es `null` si el cliente no tiene registros. | [**4**](#caso-24) (mobile 0 · backend 4) |
| HU-24 | Respuesta compatible con HU-05 y armada sin una consulta por cliente. | Unitaria | Se conservan `id`, `name`, `email` y el orden por nombre; la meta y el último registro se unen a cada cliente desde consultas en lote, sin mezclar datos de otros usuarios. | [**6**](#caso-25) (mobile 0 · backend 6) |
| HU-24 | Restricción por sesión y rol. | Integración | Sin sesión responde 401 `UNAUTHORIZED`; una cuenta de usuario responde 403 `FORBIDDEN_ROLE`. | [**2**](#caso-26) (mobile 0 · backend 2) |
| HU-24 | Contrato OpenAPI de la lista de clientes (TEC-14). | Unitaria | `ClientResponse` documenta `goal` y `last_meal_at` como obligatorios y nulables, y `goal` referencia `ClientGoalSummary`. | [**1**](#caso-27) (mobile 0 · backend 1) |
| HU-10 | Suma del día y restante contra la meta (RF-09). | Unitaria | Lo consumido es la suma de calorías, proteína y grasa de los registros del día; `remaining` es la meta menos lo consumido; los valores se redondean a 1 decimal sin ruido de punto flotante. | [**4**](#caso-28) (mobile 0 · backend 4) |
| HU-10 | Día sin registros. | Integración | Un día sin registros devuelve consumo en 0 (nunca `-0`) y restante igual a la meta. | [**3**](#caso-29) (mobile 0 · backend 3) |
| HU-10 | Consumo por encima de la meta. | Integración | Si lo consumido supera la meta, `remaining` es negativo (meta − consumido), sin recortarse a 0. | [**2**](#caso-30) (mobile 0 · backend 2) |
| HU-10 | Meta vigente con su origen (RN-06). | Integración | `goal` trae la meta vigente ese día con su origen: `system` o `coach` (la del coach tiene prioridad) y el restante se calcula con ella. | [**2**](#caso-31) (mobile 0 · backend 2) |
| HU-10 | El resumen refleja guardar y eliminar registros. | Integración | Tras guardar registros, el resumen los suma; tras eliminar uno, la siguiente consulta deja de contarlo. | [**3**](#caso-32) (mobile 0 · backend 3) |
| HU-10 | El día se define en la zona horaria de la app. | Unitaria | El día consultado termina un milisegundo antes de la medianoche local (`APP_UTC_OFFSET`, UTC−6 por defecto) para elegir la meta vigente. | [**1**](#caso-33) (mobile 0 · backend 1) |
| HU-10 | Validación de `date`. | Integración | Una fecha inválida o ausente responde 400 `VALIDATION_ERROR` con el campo `date` señalado. | [**2**](#caso-34) (mobile 0 · backend 2) |
| HU-10 | Restricción por sesión, rol y perfil. | Integración | Sin sesión responde 401 `UNAUTHORIZED`; una cuenta de coach responde 403 `FORBIDDEN_ROLE`; un usuario sin perfil ni meta responde 404 `PROFILE_NOT_FOUND`, igual que `GET /users/me/goals/current`. | [**3**](#caso-35) (mobile 0 · backend 3) |
| HU-11 | La semana son 7 días seguidos desde `start` (RF-10). | Unitaria | `start` puede ser cualquier día; la respuesta trae exactamente 7 días desde ahí (también al cruzar de mes), con `start` y `end`; una semana que se sale del calendario se rechaza. | [**3**](#caso-36) (mobile 0 · backend 3) |
| HU-11 | Totales de calorías, proteína y grasa de cada día. | Integración | Cada día trae lo consumido ese día (igual a lo enviado), la meta de ese día y el restante; los días sin registros aparecen en 0. | [**3**](#caso-37) (mobile 0 · backend 3) |
| HU-11 | Promedio diario con los días vacíos como 0. | Unitaria | El promedio es el total de los 7 días entre 7, redondeado a 1 decimal; una semana sin registros da promedio 0 (nunca `-0`). | [**3**](#caso-38) (mobile 0 · backend 3) |
| HU-11 | Día con la meta cumplida. | Unitaria | Un día cumple si consumió calorías y estas quedan entre el 90 % y el 110 % de su meta (límites incluidos); sin consumo nunca cumple; `goal_met_days` cuenta los días cumplidos. | [**6**](#caso-39) (mobile 0 · backend 6) |
| HU-11 | Meta que cambia a mitad de semana (RF-21). | Integración | Cada día se compara con la meta vigente ese día (calculada antes, del coach después), con la misma regla que `GET /users/me/goals/current`. | [**4**](#caso-40) (mobile 0 · backend 4) |
| HU-11 | Validación de `start`. | Integración | Un `start` ausente o con formato inválido responde 400 `VALIDATION_ERROR` con el campo `start` señalado. | [**3**](#caso-41) (mobile 0 · backend 3) |
| HU-11 | Restricción por sesión, rol y perfil. | Integración | Sin sesión responde 401 `UNAUTHORIZED`; una cuenta de coach responde 403 `FORBIDDEN_ROLE`; un usuario sin perfil ni meta responde 404 `PROFILE_NOT_FOUND`. | [**3**](#caso-42) (mobile 0 · backend 3) |

## Cómo se cuentan las pruebas

- **Mobile**: cada `test` o `testWidgets` de `macrofit_app/test/` (Flutter).
- **Backend**: cada prueba unitaria `#[test]` de `backend/src/` (Rust) más cada request de la colección de Postman (`backend/postman/`), que verifica el código de estado y la estructura de la respuesta. Los requests de "Preparación" (crear cuentas o iniciar sesión para los siguientes) no se cuentan.
- Una misma prueba puede contar en más de un caso cuando verifica varios criterios (p. ej. el cálculo de un perfil de referencia comprueba calorías y macros).
- No se cuentan las pruebas manuales de punta a punta ni las capturas de evidencia.

Inventario al cerrar TEC-09: **119** pruebas mobile, **<RUST>** pruebas de Rust (`cargo test`, incluidas las 6 de TEC-13 que requieren MongoDB y se ejecutan con `--ignored`) y **<POSTMAN>** requests de Postman (sin contar los de preparación). Incluye las pruebas de TEC-13, HU-12-API, HU-21-API y los 3 requests del catálogo de ejercicios de TEC-09, que todavía no tienen casos en este esquema.

Inventario al cerrar HU-24-API: **119** pruebas mobile, **181** pruebas de Rust (`cargo test`: 167 se ejecutan y 14 requieren MongoDB y se ejecutan con `--ignored`) y **143** requests de Postman en la colección combinada (sin contar los 38 de preparación). HU-24 agrega 10 pruebas de Rust y 6 requests de Postman, y actualiza *HU-05 Metas por coach › 06 - Lista de clientes del coach* al contrato nuevo.

Inventario al cerrar HU-10-API: **119** pruebas mobile, **188** pruebas de Rust (`cargo test`: 174 se ejecutan y 14 requieren MongoDB y se ejecutan con `--ignored`) y **158** requests de Postman en la colección combinada (sin contar los 48 de preparación). HU-10 agrega 7 pruebas de Rust y 15 requests de Postman (más 10 de preparación). Su endpoint está en el catálogo de `routes/openapi.rs`, así que lo cubren también las pruebas generales de TEC-14 (casos 11 a 15).

Inventario al cerrar HU-11-API: **119** pruebas mobile, **199** pruebas de Rust (`cargo test`: 185 se ejecutan y 14 requieren MongoDB y se ejecutan con `--ignored`) y **172** requests de Postman en la colección combinada (sin contar los 58 de preparación). HU-11 agrega 11 pruebas de Rust y 14 requests de Postman (más 10 de preparación) y reutiliza el cálculo diario de HU-10. Su endpoint también está en el catálogo de `routes/openapi.rs` (casos 11 a 15 de TEC-14).

## Detalle de las pruebas por caso

### <a id="caso-01"></a>Caso 01 · TEC-12 — Rangos válidos del perfil (peso, estatura, edad)

Mobile: 0 · Backend: 6

Sustituye los rangos provisionales del caso 12 del Sprint 1 (`edad_de_18_y_100_anios_es_valida_y_fuera_no` pasa a ser `edad_de_18_y_80_anios_es_valida_y_fuera_no`). La app conserva los rangos provisionales hasta el Sprint 3.

**Backend (Rust)**

- `backend/src/services/profile.rs` › `limites_de_peso_estatura_y_dias_son_inclusivos`
- `backend/src/services/profile.rs` › `valores_justo_fuera_de_los_limites_se_rechazan`
- `backend/src/services/profile.rs` › `valores_fuera_de_rango_se_senalan_todos`
- `backend/src/services/profile.rs` › `edad_de_18_y_80_anios_es_valida_y_fuera_no`

**Backend (Postman)**

- Postman › HU-03 Perfil › Valores fuera de rango
- Postman › HU-03 Perfil › Edición con valores inválidos

### <a id="caso-02"></a>Caso 02 · TEC-12 — Rango de peso reutilizable para el registro de peso (HU-21)

Mobile: 0 · Backend: 1

**Backend (Rust)**

- `backend/src/services/profile.rs` › `peso_reutilizable_aplica_el_mismo_rango`

### <a id="caso-03"></a>Caso 03 · TEC-12 — Cálculo de calorías con la fórmula confirmada

Mobile: 0 · Backend: 6

**Backend (Rust)**

- `backend/src/services/goals.rs` › `hombre_bajar_grasa_coincide_con_calculo_manual`
- `backend/src/services/goals.rs` › `mujer_ganar_musculo_coincide_con_calculo_manual`
- `backend/src/services/goals.rs` › `hombre_mantener_coincide_con_calculo_manual`
- `backend/src/services/goals.rs` › `factor_de_actividad_respeta_los_limites_de_cada_rango`

**Backend (Postman)**

- Postman › HU-04 Meta calculada › 02 - Meta inicial (consultar meta)
- Postman › HU-04 Meta calculada › 04 - Meta recalculada

### <a id="caso-04"></a>Caso 04 · TEC-12 — Distribución de proteína y grasa confirmada para cada objetivo

Mobile: 0 · Backend: 6

**Backend (Rust)**

- `backend/src/services/goals.rs` › `proteina_y_grasa_siguen_la_regla_de_cada_objetivo`
- `backend/src/services/goals.rs` › `hombre_bajar_grasa_coincide_con_calculo_manual`
- `backend/src/services/goals.rs` › `mujer_ganar_musculo_coincide_con_calculo_manual`
- `backend/src/services/goals.rs` › `hombre_mantener_coincide_con_calculo_manual`

**Backend (Postman)**

- Postman › HU-04 Meta calculada › 02 - Meta inicial (consultar meta)
- Postman › HU-04 Meta calculada › 04 - Meta recalculada

### <a id="caso-05"></a>Caso 05 · TEC-12 — Mínimo de calorías de la meta calculada

Mobile: 0 · Backend: 5

**Backend (Rust)**

- `backend/src/services/goals.rs` › `mujer_bajo_el_minimo_recibe_1200_kcal`
- `backend/src/services/goals.rs` › `hombre_bajo_el_minimo_recibe_1500_kcal`
- `backend/src/services/goals.rs` › `esquinas_del_perfil_dan_metas_validas`

**Backend (Postman)**

- Postman › HU-04 Meta calculada › 07 - Edición a un perfil bajo el mínimo
- Postman › HU-04 Meta calculada › 08 - Meta con el mínimo de calorías

### <a id="caso-06"></a>Caso 06 · HU-21 — Registro de un peso válido

Mobile: 0 · Backend: 4

**Backend (Rust)**

- `backend/src/services/weights.rs` › `peso_valido_se_acepta`
- `backend/src/services/weights.rs` › `limites_del_rango_se_aceptan`

**Backend (Postman)**

- Postman › HU-21 Registro de peso › 07 - Peso válido
- Postman › HU-21 Registro de peso › 08 - Segundo peso válido

### <a id="caso-07"></a>Caso 07 · HU-21 — Validación del peso

Mobile: 0 · Backend: 7

**Backend (Rust)**

- `backend/src/services/weights.rs` › `peso_ausente_o_nulo_es_obligatorio`
- `backend/src/services/weights.rs` › `peso_no_numerico_se_senala`
- `backend/src/services/weights.rs` › `peso_fuera_de_rango_usa_el_rango_del_perfil`
- `backend/src/services/profile.rs` › `peso_reutilizable_aplica_el_mismo_rango`

**Backend (Postman)**

- Postman › HU-21 Registro de peso › 04 - Sin peso
- Postman › HU-21 Registro de peso › 05 - Valor no numérico
- Postman › HU-21 Registro de peso › 06 - Peso fuera de rango

### <a id="caso-08"></a>Caso 08 · HU-21 — Historial de peso del usuario

Mobile: 0 · Backend: 2

**Backend (Postman)**

- Postman › HU-21 Registro de peso › 09 - Peso de otro usuario
- Postman › HU-21 Registro de peso › 10 - Historial

### <a id="caso-09"></a>Caso 09 · HU-21 — Restricción por sesión y rol

Mobile: 0 · Backend: 3

**Backend (Postman)**

- Postman › HU-21 Registro de peso › 01 - Sin sesión
- Postman › HU-21 Registro de peso › 02 - Registro por un coach
- Postman › HU-21 Registro de peso › 03 - Historial por un coach

### <a id="caso-10"></a>Caso 10 · HU-21 — El último peso actualiza el perfil y la meta

Mobile: 0 · Backend: 2

**Backend (Postman)**

- Postman › HU-21 Registro de peso › 11 - Perfil con el último peso
- Postman › HU-21 Registro de peso › 12 - Meta recalculada con el último peso

### <a id="caso-11"></a>Caso 11 · TEC-14 — La especificación se genera desde el código e incluye todo el catálogo

Mobile: 0 · Backend: 2

La especificación se arma al compilar con `utoipa` a partir de los handlers y DTOs; `CATALOG` en las pruebas replica el catálogo de endpoints del README.

**Backend (Rust)**

- `backend/src/routes/openapi.rs` › `la_especificacion_incluye_todos_los_endpoints_del_catalogo`

**Backend (Postman)**

- Postman › TEC-14 Contrato OpenAPI › Especificación OpenAPI

### <a id="caso-12"></a>Caso 12 · TEC-14 — Cada operación documentada existe en el router

Mobile: 0 · Backend: 1

Llama cada operación de la especificación sobre `routes::api_router` (sin sesión y con cuerpo `{}`), así que un endpoint documentado con una ruta o un método que no existe falla la prueba.

**Backend (Rust)**

- `backend/src/routes/openapi.rs` › `cada_operacion_documentada_existe_en_el_router`

### <a id="caso-13"></a>Caso 13 · TEC-14 — Cuerpo de petición, respuesta y códigos de error de cada endpoint

Mobile: 0 · Backend: 3

**Backend (Rust)**

- `backend/src/routes/openapi.rs` › `cada_operacion_documenta_sus_codigos_de_estado`
- `backend/src/routes/openapi.rs` › `cada_respuesta_exitosa_documenta_su_cuerpo`
- `backend/src/routes/openapi.rs` › `las_operaciones_con_cuerpo_documentan_la_peticion`

### <a id="caso-14"></a>Caso 14 · TEC-14 — Formato de error definido una sola vez

Mobile: 0 · Backend: 3

`AppError` se serializa con el struct `ErrorResponse`, el mismo que documenta la especificación.

**Backend (Rust)**

- `backend/src/routes/openapi.rs` › `todas_las_respuestas_de_error_usan_el_esquema_comun`
- `backend/src/error.rs` › `el_error_serializado_tiene_la_forma_documentada`

**Backend (Postman)**

- Postman › TEC-14 Contrato OpenAPI › Especificación OpenAPI

### <a id="caso-15"></a>Caso 15 · TEC-14 — Esquema Bearer aplicado a las rutas protegidas con su rol

Mobile: 0 · Backend: 2

**Backend (Rust)**

- `backend/src/routes/openapi.rs` › `rutas_protegidas_declaran_bearer_y_rol`

**Backend (Postman)**

- Postman › TEC-14 Contrato OpenAPI › Especificación OpenAPI

### <a id="caso-16"></a>Caso 16 · TEC-14 — Rutas `/dev` solo con `APP_ENV=development`

Mobile: 0 · Backend: 3

El request de Postman funciona en ambos ambientes: comprueba que la ruta exista (400) exactamente cuando la especificación la documenta, y que no exista (404) cuando no.

**Backend (Rust)**

- `backend/src/routes/openapi.rs` › `rutas_dev_solo_en_desarrollo`
- `backend/src/routes/openapi.rs` › `ruta_dev_no_existe_fuera_de_desarrollo`

**Backend (Postman)**

- Postman › TEC-14 Contrato OpenAPI › Rutas /dev según el ambiente

### <a id="caso-17"></a>Caso 17 · TEC-14 — Documentación visible en una ruta del catálogo

Mobile: 0 · Backend: 2

**Backend (Rust)**

- `backend/src/routes/openapi.rs` › `la_documentacion_se_sirve_en_docs`

**Backend (Postman)**

- Postman › TEC-14 Contrato OpenAPI › Documentación (Swagger UI)

### <a id="caso-18"></a>Caso 18 · TEC-09 — Catálogo base con cantidad mínima acordada (18 ejercicios) y cobertura de combinaciones

Mobile: 0 · Backend: 5

Verifica que el catálogo inicial cuenta con la cantidad mínima de ejercicios acordada en el Sprint Planning (18 ejercicios) y que existe al menos un ejercicio para cada una de las 18 combinaciones de grupo muscular (`chest`, `back`, `legs`, `shoulders`, `arms`, `core`) y nivel (`beginner`, `intermediate`, `advanced`), requisito para que el motor de reglas (TEC-10 / RF-14) genere una rutina válida en cualquier caso.

**Backend (Rust)**

- `backend/src/services/exercises.rs` › `cantidad_minima_de_ejercicios_cumple_acuerdo_sprint_planning`
- `backend/src/services/exercises.rs` › `el_catalogo_contiene_ejercicios_para_todas_las_combinaciones`
- `backend/src/services/exercises.rs` › `grupos_musculares_son_los_seis_esperados`
- `backend/src/services/exercises.rs` › `todos_los_nombres_del_catalogo_son_unicos_y_no_vacios`

**Backend (Postman)**

- Postman › TEC-09 Catálogo de ejercicios › 02 - Consultar catálogo de ejercicios

### <a id="caso-19"></a>Caso 19 · TEC-09 — Niveles de dificultad idénticos al perfil y grupos musculares

Mobile: 0 · Backend: 3

Comprueba que los niveles de dificultad del catálogo coinciden exactamente con los del perfil de usuario (`beginner`, `intermediate`, `advanced`) y que la conversión y validación de enumerados procesa entradas válidas e inválidas.

**Backend (Rust)**

- `backend/src/services/exercises.rs` › `niveles_de_ejercicios_coinciden_con_los_niveles_del_perfil`
- `backend/src/models/exercise.rs` › `parse_muscle_group_acepta_todos_los_validos_y_rechaza_invalidos`
- `backend/src/models/exercise.rs` › `parse_exercise_level_acepta_todos_los_validos_y_rechaza_invalidos`

### <a id="caso-20"></a>Caso 20 · TEC-09 — Carga reproducible e idempotente sin duplicación de ejercicios

Mobile: 0 · Backend: 2

Comprueba que el script de carga (`seed_exercises`) utiliza `find_one_and_update` con `upsert: true` sobre el índice único `name` (`exercise_name_unique`), de modo que ejecutarlo dos o más veces actualiza la información sin duplicar documentos en la colección `exercises` ni generar errores de clave duplicada.

**Backend (Rust)**

- `backend/src/services/exercises.rs` › `seed_exercises_es_reproducible_e_idempotente`

**Backend (Postman)**

- Postman › TEC-09 Catálogo de ejercicios › 01 - Sembrar catálogo de ejercicios

### <a id="caso-21"></a>Caso 21 · TEC-09 — Consulta y filtrado del catálogo de ejercicios vía API REST

Mobile: 0 · Backend: 4

Comprueba los endpoints de la API: `GET /api/v1/exercises` responde la lista completa serializada correctamente, soporta filtrado por `muscle_group` y `level`, y `POST /api/v1/dev/seed/exercises` permite la siembra en ambientes de desarrollo.

**Backend (Rust)**

- `backend/src/routes/exercises.rs` › `exercise_response_serializa_todos_los_campos`

**Backend (Postman)**

- Postman › TEC-09 Catálogo de ejercicios › 01 - Sembrar catálogo de ejercicios
- Postman › TEC-09 Catálogo de ejercicios › 02 - Consultar catálogo de ejercicios
- Postman › TEC-09 Catálogo de ejercicios › 03 - Filtrar por grupo muscular y nivel

### <a id="caso-22"></a>Caso 22 · HU-24 — Solo clientes con vínculo activo

Mobile: 0 · Backend: 1

La carpeta crea su propio coach y tres clientes vinculados con el código de invitación (HU-12/HU-13); Carla se desvincula (HU-14) antes de consultar.

**Backend (Postman)**

- Postman › HU-24 Lista de clientes › 03 - Coach con clientes

### <a id="caso-23"></a>Caso 23 · HU-24 — Resumen de la meta vigente

Mobile: 0 · Backend: 5

`pick_current_goals` aplica en lote la misma regla que `GET /users/me/goals/current` sobre las metas de todos los clientes, obtenidas con una sola consulta.

**Backend (Rust)**

- `backend/src/services/goals.rs` › `meta_vigente_en_lote_prioriza_la_del_coach_mas_reciente`
- `backend/src/services/goals.rs` › `meta_vigente_en_lote_ignora_las_futuras_y_toma_la_calculada_mas_reciente`
- `backend/src/services/goals.rs` › `meta_vigente_en_lote_omite_usuarios_sin_metas_vigentes`

**Backend (Postman)**

- Postman › HU-24 Lista de clientes › 04 - Cliente sin registros (fecha null)
- Postman › HU-24 Lista de clientes › 06 - Cliente con meta del coach

### <a id="caso-24"></a>Caso 24 · HU-24 — Fecha del último registro de comida

Mobile: 0 · Backend: 4

Una agregación sobre `meals` (`$match` por los clientes y `$group` con `$max` de `eaten_at`) da el último registro de todos los clientes a la vez.

**Backend (Rust)**

- `backend/src/services/meals.rs` › `ultimo_registro_se_agrupa_por_usuario_en_una_sola_agregacion`
- `backend/src/services/meals.rs` › `ultimo_registro_se_lee_por_usuario_e_ignora_filas_incompletas`

**Backend (Postman)**

- Postman › HU-24 Lista de clientes › 04 - Cliente sin registros (fecha null)
- Postman › HU-24 Lista de clientes › 05 - Cliente con registro (fecha del último)

### <a id="caso-25"></a>Caso 25 · HU-24 — Respuesta compatible con HU-05 y armada en lote

Mobile: 0 · Backend: 6

La app usa la lista desde HU-05 y solo lee `id`, `name` y `email`; los campos nuevos se agregan sin quitar ninguno.

**Backend (Rust)**

- `backend/src/services/coach_links.rs` › `la_lista_une_meta_y_ultimo_registro_de_cada_cliente`
- `backend/src/services/coach_links.rs` › `la_lista_conserva_el_orden_por_nombre_y_no_mezcla_datos_ajenos`
- `backend/src/routes/goals.rs` › `cliente_con_meta_y_registro_se_serializa_con_el_contrato`
- `backend/src/routes/goals.rs` › `cliente_sin_meta_ni_registros_conserva_los_campos_en_null`

**Backend (Postman)**

- Postman › HU-24 Lista de clientes › 03 - Coach con clientes
- Postman › HU-05 Metas por coach › 06 - Lista de clientes del coach

### <a id="caso-26"></a>Caso 26 · HU-24 — Restricción por sesión y rol

Mobile: 0 · Backend: 2

**Backend (Postman)**

- Postman › HU-24 Lista de clientes › 01 - Sin sesión
- Postman › HU-24 Lista de clientes › 02 - Cuenta de usuario

### <a id="caso-27"></a>Caso 27 · HU-24 — Contrato OpenAPI de la lista de clientes

Mobile: 0 · Backend: 1

**Backend (Rust)**

- `backend/src/routes/openapi.rs` › `lista_de_clientes_documenta_meta_y_ultimo_registro`

### <a id="caso-28"></a>Caso 28 · HU-10 — Suma del día y restante contra la meta

Mobile: 0 · Backend: 4

`build_daily_summary` es una función pura: suma los registros del día y resta de la meta. Los valores se redondean a 1 decimal.

**Backend (Rust)**

- `backend/src/services/summary.rs` › `suma_los_registros_y_resta_de_la_meta`
- `backend/src/services/summary.rs` › `redondea_a_un_decimal_sin_ruido_de_punto_flotante`

**Backend (Postman)**

- Postman › HU-10 Resumen diario › 04 - Día con registros
- Postman › HU-10 Resumen diario › 06 - Resumen tras eliminar un registro

### <a id="caso-29"></a>Caso 29 · HU-10 — Día sin registros

Mobile: 0 · Backend: 3

La suma de un iterador vacío de `f64` da `-0.0`; el resumen lo normaliza a `0` para que el cliente no reciba `-0`.

**Backend (Rust)**

- `backend/src/services/summary.rs` › `un_dia_sin_registros_consume_cero_y_el_restante_es_la_meta`
- `backend/src/services/summary.rs` › `un_dia_sin_registros_no_devuelve_cero_negativo`

**Backend (Postman)**

- Postman › HU-10 Resumen diario › 01 - Día sin registros

### <a id="caso-30"></a>Caso 30 · HU-10 — Consumo por encima de la meta

Mobile: 0 · Backend: 2

`remaining` = meta − consumido y puede ser negativo (por ejemplo `-150` = se pasó por 150).

**Backend (Rust)**

- `backend/src/services/summary.rs` › `el_restante_es_negativo_cuando_el_consumo_supera_la_meta`

**Backend (Postman)**

- Postman › HU-10 Resumen diario › 08 - Consumo por encima de la meta: el restante es negativo

### <a id="caso-31"></a>Caso 31 · HU-10 — Meta vigente con su origen

Mobile: 0 · Backend: 2

La meta se obtiene con `goals::get_goal_at`, que aplica la misma regla que `GET /users/me/goals/current`: la del coach tiene prioridad sobre la calculada.

**Backend (Rust)**

- `backend/src/services/summary.rs` › `el_origen_de_la_meta_se_conserva`

**Backend (Postman)**

- Postman › HU-10 Resumen diario › 15 - Resumen con la meta del coach

### <a id="caso-32"></a>Caso 32 · HU-10 — El resumen refleja guardar y eliminar registros

Mobile: 0 · Backend: 3

La carpeta guarda dos registros, consulta el resumen, elimina uno y vuelve a consultar. Los valores esperados se calculan a partir de lo enviado.

**Backend (Postman)**

- Postman › HU-10 Resumen diario › 04 - Día con registros
- Postman › HU-10 Resumen diario › 05 - Eliminar un registro
- Postman › HU-10 Resumen diario › 06 - Resumen tras eliminar un registro

### <a id="caso-33"></a>Caso 33 · HU-10 — El día se define en la zona horaria de la app

Mobile: 0 · Backend: 1

El día de HU-09 se calcula con `APP_UTC_OFFSET`; el resumen toma la meta vigente al final de ese mismo día.

**Backend (Rust)**

- `backend/src/services/summary.rs` › `el_dia_termina_un_milisegundo_antes_de_la_medianoche_local`

### <a id="caso-34"></a>Caso 34 · HU-10 — Validación de `date`

Mobile: 0 · Backend: 2

**Backend (Postman)**

- Postman › HU-10 Resumen diario › 09 - Fecha inválida
- Postman › HU-10 Resumen diario › 10 - Sin fecha

### <a id="caso-35"></a>Caso 35 · HU-10 — Restricción por sesión, rol y perfil

Mobile: 0 · Backend: 3

**Backend (Postman)**

- Postman › HU-10 Resumen diario › 11 - Sin sesión
- Postman › HU-10 Resumen diario › 12 - Cuenta de coach
- Postman › HU-10 Resumen diario › 13 - Usuario sin meta vigente

### <a id="caso-36"></a>Caso 36 · HU-11 — La semana son 7 días seguidos desde `start`

Mobile: 0 · Backend: 3

**Backend (Rust)**

- `backend/src/services/summary.rs` › `la_semana_son_siete_dias_seguidos_aunque_cambie_el_mes`
- `backend/src/services/summary.rs` › `una_semana_que_se_sale_del_calendario_se_rechaza`

**Backend (Postman)**

- Postman › HU-11 Resumen semanal › 01 - Semana sin registros

### <a id="caso-37"></a>Caso 37 · HU-11 — Totales de calorías, proteína y grasa de cada día

Mobile: 0 · Backend: 3

La carpeta guarda registros de hoy y consulta la semana tres veces; el consumo esperado se calcula a partir de lo enviado.

**Backend (Postman)**

- Postman › HU-11 Resumen semanal › 03 - Semana con registros por debajo del 90 %
- Postman › HU-11 Resumen semanal › 05 - Semana con el día en la meta (100 %)
- Postman › HU-11 Resumen semanal › 07 - Semana con el día por encima del 110 %

### <a id="caso-38"></a>Caso 38 · HU-11 — Promedio diario con los días vacíos como 0

Mobile: 0 · Backend: 3

**Backend (Rust)**

- `backend/src/services/summary.rs` › `el_promedio_cuenta_los_dias_sin_registros_como_cero`
- `backend/src/services/summary.rs` › `una_semana_vacia_no_devuelve_ceros_negativos`

**Backend (Postman)**

- Postman › HU-11 Resumen semanal › 01 - Semana sin registros

### <a id="caso-39"></a>Caso 39 · HU-11 — Día con la meta cumplida

Mobile: 0 · Backend: 6

Calorías entre el 90 % y el 110 % de la meta del día. En Postman el mismo día pasa de 50 % (no cumple) a 100 % (cumple) y a 150 % (no cumple).

**Backend (Rust)**

- `backend/src/services/summary.rs` › `la_meta_se_cumple_entre_el_90_y_el_110_por_ciento_con_limites_incluidos`
- `backend/src/services/summary.rs` › `sin_consumo_la_meta_nunca_se_cumple`
- `backend/src/services/summary.rs` › `cuenta_los_dias_que_cumplen_la_meta_y_marca_cada_uno`

**Backend (Postman)**

- Postman › HU-11 Resumen semanal › 03 - Semana con registros por debajo del 90 %
- Postman › HU-11 Resumen semanal › 05 - Semana con el día en la meta (100 %)
- Postman › HU-11 Resumen semanal › 07 - Semana con el día por encima del 110 %

### <a id="caso-40"></a>Caso 40 · HU-11 — Meta que cambia a mitad de semana

Mobile: 0 · Backend: 4

`pick_goal_at` aplica la regla de la meta vigente a cualquier instante; la semana la usa una vez por día con una sola consulta (`get_goals_at`). En Postman el coach fija una meta que empieza a mitad de semana; el día justo antes del inicio no se comprueba porque la fecha de la meta es una fecha en UTC y ese día puede quedar a uno u otro lado según la zona horaria.

**Backend (Rust)**

- `backend/src/services/summary.rs` › `cada_dia_se_compara_con_la_meta_vigente_ese_dia`
- `backend/src/services/goals.rs` › `meta_a_una_fecha_cambia_a_mitad_de_semana_y_la_del_coach_gana`
- `backend/src/services/goals.rs` › `meta_a_una_fecha_anterior_a_la_primera_meta_no_existe`

**Backend (Postman)**

- Postman › HU-11 Resumen semanal › 14 - Cada día con la meta que regía ese día (RF-21)

### <a id="caso-41"></a>Caso 41 · HU-11 — Validación de `start`

Mobile: 0 · Backend: 3

**Backend (Rust)**

- `backend/src/services/summary.rs` › `start_ausente_o_con_formato_invalido_senala_el_campo_start`

**Backend (Postman)**

- Postman › HU-11 Resumen semanal › 08 - Start inválido
- Postman › HU-11 Resumen semanal › 09 - Sin start

### <a id="caso-42"></a>Caso 42 · HU-11 — Restricción por sesión, rol y perfil

Mobile: 0 · Backend: 3

**Backend (Postman)**

- Postman › HU-11 Resumen semanal › 10 - Sin sesión
- Postman › HU-11 Resumen semanal › 11 - Cuenta de coach
- Postman › HU-11 Resumen semanal › 12 - Usuario sin meta vigente
