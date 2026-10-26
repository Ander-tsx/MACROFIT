## Casos de prueba

<!-- Los casos 01 a 13 (HU-24-APP y HU-25-APP) se integran con su pull request; TEC-10 empieza en el caso 14 para no repetir anclas. -->

| Historia de usuario | ¿Qué comprueba? | Tipo | Criterio de aprobación | Pruebas realizadas |
|---|---|---|---|---|
| TEC-10 | Las 63 combinaciones de objetivo (3), nivel (3) y días por semana (1 a 7) generan una rutina válida (RF-14). | Unitaria | Con el catálogo de TEC-09, cada combinación devuelve una rutina con al menos un ejercicio por sesión, un ejercicio de cada grupo del foco de la sesión, sin ejercicios repetidos en una sesión y solo con ejercicios del catálogo. | [**1**](#caso-14) (mobile 0 · backend 1) |
| TEC-10 | La cantidad de sesiones no excede la disponibilidad (RF-14). | Unitaria | Se genera una sesión por día de entrenamiento (1 a 7); `training_days` fuera de 1 a 7 responde `InvalidTrainingDays`. | [**2**](#caso-15) (mobile 0 · backend 2) |
| TEC-10 | División por grupo muscular según los días. | Unitaria | 1–3 días: *Cuerpo completo*; 4 días: *Torso* / *Pierna* alternados; 5–7 días: *Empuje* / *Tirón* / *Pierna* en rotación; las sesiones se llaman `Día N · <foco>`; 1 ejercicio por grupo en cuerpo completo y 1 / 2 / 2–3 en las divisiones según el nivel. | [**5**](#caso-16) (mobile 0 · backend 5) |
| TEC-10 | Solo ejercicios del nivel del usuario o inferiores. | Unitaria | Ningún ejercicio supera el nivel del perfil y, a igual grupo, se eligen primero los del nivel del usuario. | [**2**](#caso-17) (mobile 0 · backend 2) |
| TEC-10 | Series, repeticiones y descanso por nivel y objetivo. | Unitaria | Series 2 / 3 / 4 (principiante / intermedio / avanzado); 10 reps y 90 s (`gain_muscle`), 12 reps y 60 s (`maintain`), 15 reps y 45 s (`lose_fat`); series y repeticiones mayores a cero (mismas reglas que HU-18-API). | [**1**](#caso-18) (mobile 0 · backend 1) |
| TEC-10 | Resultado determinista y catálogo incompleto. | Unitaria | El mismo perfil y catálogo dan la misma rutina aunque el catálogo llegue en otro orden; un grupo sin ejercicios elegibles (falta el grupo o solo hay ejercicios de nivel superior) responde `MissingExercises` con el grupo y el nivel, sin fallar. | [**4**](#caso-19) (mobile 0 · backend 4) |

## Cómo se cuentan las pruebas

- **Mobile**: cada `test` o `testWidgets` de `macrofit_app/test/` (Flutter).
- **Backend**: cada prueba unitaria `#[test]` de `backend/src/` (Rust) más cada request de la colección de Postman (`backend/postman/`), que verifica el código de estado y la estructura de la respuesta. Los requests de "Preparación" (crear cuentas o iniciar sesión para los siguientes) no se cuentan.
- Una misma prueba puede contar en más de un caso cuando verifica varios criterios.
- No se cuentan las pruebas manuales de punta a punta ni las capturas de evidencia.

Inventario al cerrar TEC-10: **235** pruebas de Rust (`cargo test`: 217 se ejecutan y 18 requieren MongoDB y se ejecutan con `--ignored`). TEC-10 agrega 15 pruebas de Rust en `backend/src/services/routine_engine.rs`. No tiene endpoint (lo expone HU-15-API), así que la colección de Postman y la app no cambian.

## Detalle de las pruebas por caso

### <a id="caso-14"></a>Caso 14 · TEC-10 — Las 63 combinaciones generan una rutina válida (RF-14)

Mobile: 0 · Backend: 1

**Backend (Rust)**

- `backend/src/services/routine_engine.rs` › `las_63_combinaciones_generan_una_rutina_valida`

### <a id="caso-15"></a>Caso 15 · TEC-10 — Sesiones según la disponibilidad (RF-14)

Mobile: 0 · Backend: 2

**Backend (Rust)**

- `backend/src/services/routine_engine.rs` › `el_numero_de_sesiones_es_igual_a_los_dias_de_entrenamiento`
- `backend/src/services/routine_engine.rs` › `dias_fuera_de_1_a_7_responden_error`

### <a id="caso-16"></a>Caso 16 · TEC-10 — División por grupo muscular

Mobile: 0 · Backend: 5

**Backend (Rust)**

- `backend/src/services/routine_engine.rs` › `de_1_a_3_dias_es_cuerpo_completo`
- `backend/src/services/routine_engine.rs` › `con_4_dias_alterna_torso_y_pierna`
- `backend/src/services/routine_engine.rs` › `de_5_a_7_dias_rota_empuje_tiron_y_pierna`
- `backend/src/services/routine_engine.rs` › `las_sesiones_se_numeran_con_su_foco`
- `backend/src/services/routine_engine.rs` › `ejercicios_por_grupo_segun_nivel_y_sesion`

### <a id="caso-17"></a>Caso 17 · TEC-10 — Ejercicios del nivel del usuario o inferiores

Mobile: 0 · Backend: 2

**Backend (Rust)**

- `backend/src/services/routine_engine.rs` › `solo_elige_ejercicios_del_nivel_del_usuario_o_inferiores`
- `backend/src/services/routine_engine.rs` › `prefiere_los_ejercicios_del_nivel_del_usuario`

### <a id="caso-18"></a>Caso 18 · TEC-10 — Series, repeticiones y descanso

Mobile: 0 · Backend: 1

**Backend (Rust)**

- `backend/src/services/routine_engine.rs` › `series_por_nivel_y_repeticiones_y_descanso_por_objetivo`

### <a id="caso-19"></a>Caso 19 · TEC-10 — Determinismo y catálogo incompleto

Mobile: 0 · Backend: 4

**Backend (Rust)**

- `backend/src/services/routine_engine.rs` › `mismo_perfil_y_catalogo_dan_la_misma_rutina`
- `backend/src/services/routine_engine.rs` › `el_orden_del_catalogo_no_cambia_la_rutina`
- `backend/src/services/routine_engine.rs` › `catalogo_sin_un_grupo_responde_error_propio`
- `backend/src/services/routine_engine.rs` › `catalogo_sin_ejercicios_del_nivel_responde_error_propio`
