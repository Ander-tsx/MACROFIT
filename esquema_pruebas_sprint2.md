## Casos de prueba

| Historia de usuario | ¿Qué comprueba? | Tipo | Criterio de aprobación | Pruebas realizadas |
|---|---|---|---|---|
| TEC-12 | Rangos válidos del perfil confirmados (peso 35–250 kg, estatura 130–230 cm, edad 18–80 años). | Unitaria | Los límites se aceptan; un valor justo fuera de cada límite se rechaza en su campo con `VALIDATION_ERROR`. | [**6**](#caso-01) (mobile 0 · backend 6) |
| TEC-12 | Rango de peso reutilizable para el registro de peso (HU-21). | Unitaria | `parse_weight_kg` acepta 35 y 250 kg y rechaza lo que queda fuera con el mismo mensaje que el perfil. | [**1**](#caso-02) (mobile 0 · backend 1) |
| TEC-12 | Cálculo de calorías con la fórmula confirmada. | Unitaria | Para al menos 3 perfiles de referencia, el resultado coincide con el cálculo manual de Mifflin-St Jeor (± 1). | [**6**](#caso-03) (mobile 0 · backend 6) |
| TEC-12 | Distribución de proteína y grasa confirmada para cada objetivo. | Unitaria | Para bajar grasa, mantener y ganar músculo, la proteína es 2.0, 1.6 y 1.8 g/kg y la grasa el 25 % de las calorías. | [**6**](#caso-04) (mobile 0 · backend 6) |
| TEC-12 | Mínimo de calorías de la meta calculada. | Integración | Un cálculo bajo el mínimo sube a 1 200 kcal (mujer) o 1 500 kcal (hombre), con la grasa calculada sobre ese mínimo; en los límites del perfil la meta queda entre el mínimo y 10 000 kcal. | [**5**](#caso-05) (mobile 0 · backend 5) |
| TEC-09 | Catálogo base con cantidad mínima acordada (18 ejercicios) y cobertura de todas las combinaciones de grupo muscular y nivel (RF-14). | Unitaria | Al menos 18 ejercicios registrados; cada combinación de los 6 grupos musculares y 3 niveles tiene al menos un ejercicio; nombres únicos y no vacíos. | [**5**](#caso-06) (mobile 0 · backend 5) |
| TEC-09 | Niveles de dificultad idénticos al perfil (beginner, intermediate, advanced) y grupos musculares esperados. | Unitaria | Los niveles de ejercicio coinciden con `Level` de `UserProfile`; los parsers aceptan valores válidos y rechazan inválidos. | [**3**](#caso-07) (mobile 0 · backend 3) |
| TEC-09 | Carga reproducible e idempotente sin duplicación de ejercicios. | Integración | Ejecutar `seed_exercises` repetidas veces mantiene exactamente 18 ejercicios en la colección `exercises` sin duplicados. | [**2**](#caso-08) (mobile 0 · backend 2) |
| TEC-09 | Consulta y filtrado del catálogo de ejercicios vía API REST. | Integración | `GET /api/v1/exercises` responde la lista completa; los parámetros de consulta `muscle_group` y `level` filtran correctamente; `POST /api/v1/dev/seed/exercises` realiza la siembra en desarrollo. | [**4**](#caso-09) (mobile 0 · backend 4) |

## Cómo se cuentan las pruebas

- **Mobile**: cada `test` o `testWidgets` de `macrofit_app/test/` (Flutter).
- **Backend**: cada prueba unitaria `#[test]` de `backend/src/` (Rust) más cada request de la colección de Postman (`backend/postman/`), que verifica el código de estado y la estructura de la respuesta. Los requests de "Preparación" (crear cuentas o iniciar sesión para los siguientes) no se cuentan.
- Una misma prueba puede contar en más de un caso cuando verifica varios criterios (p. ej. el cálculo de un perfil de referencia comprueba calorías y macros).
- No se cuentan las pruebas manuales de punta a punta ni las capturas de evidencia.

Inventario al cerrar TEC-09: **119** pruebas mobile, **73** pruebas unitarias de Rust y **78** requests de Postman (sin contar los de preparación). Incluye las pruebas de TEC-13 y HU-12-API, y los 3 requests del catálogo de ejercicios de TEC-09.

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

### <a id="caso-06"></a>Caso 06 · TEC-09 — Catálogo base con cantidad mínima acordada (18 ejercicios) y cobertura de combinaciones

Mobile: 0 · Backend: 5

Verifica que el catálogo inicial cuenta con la cantidad mínima de ejercicios acordada en el Sprint Planning (18 ejercicios) y que existe al menos un ejercicio para cada una de las 18 combinaciones de grupo muscular (`chest`, `back`, `legs`, `shoulders`, `arms`, `core`) y nivel (`beginner`, `intermediate`, `advanced`), requisito para que el motor de reglas (TEC-10 / RF-14) genere una rutina válida en cualquier caso.

**Backend (Rust)**

- `backend/src/services/exercises.rs` › `cantidad_minima_de_ejercicios_cumple_acuerdo_sprint_planning`
- `backend/src/services/exercises.rs` › `el_catalogo_contiene_ejercicios_para_todas_las_combinaciones`
- `backend/src/services/exercises.rs` › `grupos_musculares_son_los_seis_esperados`
- `backend/src/services/exercises.rs` › `todos_los_nombres_del_catalogo_son_unicos_y_no_vacios`

**Backend (Postman)**

- Postman › TEC-09 Catálogo de ejercicios › 02 - Consultar catálogo de ejercicios

### <a id="caso-07"></a>Caso 07 · TEC-09 — Niveles de dificultad idénticos al perfil y grupos musculares

Mobile: 0 · Backend: 3

Comprueba que los niveles de dificultad del catálogo coinciden exactamente con los del perfil de usuario (`beginner`, `intermediate`, `advanced`) y que la conversión y validación de enumerados procesa entradas válidas e inválidas.

**Backend (Rust)**

- `backend/src/services/exercises.rs` › `niveles_de_ejercicios_coinciden_con_los_niveles_del_perfil`
- `backend/src/models/exercise.rs` › `parse_muscle_group_acepta_todos_los_validos_y_rechaza_invalidos`
- `backend/src/models/exercise.rs` › `parse_exercise_level_acepta_todos_los_validos_y_rechaza_invalidos`

### <a id="caso-08"></a>Caso 08 · TEC-09 — Carga reproducible e idempotente sin duplicación de ejercicios

Mobile: 0 · Backend: 2

Comprueba que el script de carga (`seed_exercises`) utiliza `find_one_and_update` con `upsert: true` sobre el índice único `name` (`exercise_name_unique`), de modo que ejecutarlo dos o más veces actualiza la información sin duplicar documentos en la colección `exercises` ni generar errores de clave duplicada.

**Backend (Rust)**

- `backend/src/services/exercises.rs` › `seed_exercises_es_reproducible_e_idempotente`

**Backend (Postman)**

- Postman › TEC-09 Catálogo de ejercicios › 01 - Sembrar catálogo de ejercicios

### <a id="caso-09"></a>Caso 09 · TEC-09 — Consulta y filtrado del catálogo de ejercicios vía API REST

Mobile: 0 · Backend: 4

Comprueba los endpoints de la API: `GET /api/v1/exercises` responde la lista completa serializada correctamente, soporta filtrado por `muscle_group` y `level`, y `POST /api/v1/dev/seed/exercises` permite la siembra en ambientes de desarrollo.

**Backend (Rust)**

- `backend/src/routes/exercises.rs` › `exercise_response_serializa_todos_los_campos`

**Backend (Postman)**

- Postman › TEC-09 Catálogo de ejercicios › 01 - Sembrar catálogo de ejercicios
- Postman › TEC-09 Catálogo de ejercicios › 02 - Consultar catálogo de ejercicios
- Postman › TEC-09 Catálogo de ejercicios › 03 - Filtrar por grupo muscular y nivel
