# `features/progress/` — peso y progreso del usuario

| Historia | Qué hace |
|---|---|
| HU-21 | Registro e historial de peso (`/user/weights`) |
| HU-23 | El mismo contenido para el coach, desde el detalle del cliente (`features/clients/presentation/client_progress/`) |
| HU-22 | "Mi progreso" (`/user/progress`, pestaña **Progreso** de la barra inferior): gráficas de peso, consumo por día contra la meta y cumplimiento de entrenamiento, por semana o por mes (RF-18) |

## Archivos

| Archivo | Contenido |
|---|---|
| `domain/entities/weight_entry.dart` | Registro de peso (HU-21) |
| `domain/entities/progress_report.dart` | `ProgressReport` (HU-22): `weights`, `days` (consumo contra la meta de cada día) y `compliance` (sesiones por semana), con `hasWeightTrend`, `hasMeals` y `hasCompliance` |
| `domain/entities/progress_period.dart` | `ProgressPeriod` y `ProgressRange` (semana / mes): periodo actual, anterior y siguiente sin pasar de hoy |
| `domain/repositories/` | `WeightsRepository` (HU-21) y `ProgressRepository` (`getProgress` HU-22, `getClientProgress` HU-23) |
| `domain/usecases/goal_rules.dart` | `withinGoal`: entre el 90 % y el 110 % de la meta (la regla de `goal_met` del backend) |
| `data/datasources/progress_remote_data_source.dart` | `GET /users/me/progress` y `GET /coach/clients/{id}/progress` (`?from=&to=`) con el cliente con sesión |
| `data/models/progress_model.dart` | `ProgressResponse` → `ProgressReport` (contrato abajo; acepta también las claves del contrato provisional) |
| `presentation/weights/` | Pantalla y ViewModel del registro de peso (HU-21) |
| `presentation/shared/progress_charts_view_model.dart` | `ProgressChartsViewModel` (abstracto): periodo, reporte, carga, error y macro elegido; descarta respuestas de un periodo que ya no se ve. Cada pantalla implementa `fetch` y, si lo necesita, `handleError` |
| `presentation/shared/progress_charts.dart` | `ProgressCharts`: selector semana/mes, píldora del periodo y tres tarjetas (**Peso**, **Consumo por día**, **Entrenamiento**). Recibe `ProgressCopy` (`self` / `client`), `keyPrefix` y `onRegisterWeight` (sin él, la tarjeta de peso es de solo lectura) |
| `presentation/shared/progress_texts.dart` | Etiquetas de periodo y ejes y cambio de peso |
| `presentation/progress_charts/` | `ProgressViewModel` (`fetch` = `getProgress`) y `ProgressView` (HU-22) |

Las gráficas son widgets **sin estado** de `core/presentation/widgets/charts/` (`TrendLineChart`, `TargetBarChart`,
`RatioBars`) que reciben sus datos por parámetro: Las tarjetas que las usan y el estado del periodo están en
`presentation/shared/` y los reutiliza HU-23 (progreso del cliente para el coach) desde `features/clients`. Es una
**excepción documentada** a la regla "una feature solo usa el dominio de otra" (AGENTS.md §3), aprobada para no
duplicar las gráficas; nada fuera de `shared/` debe importarse desde otra feature.

## Flujo (HU-22)

1. Abre en la **semana que termina hoy** (7 días, como el resumen semanal de HU-11). **Semana / Mes** cambia el tamaño
   y vuelve al periodo que incluye hoy; el mes va del día 1 a su último día (el actual, hasta hoy).
2. Las flechas van al periodo anterior y al siguiente; **siguiente** se deshabilita si empezaría en el futuro.
3. **Peso**: el último peso del periodo, su cambio y la tendencia; con menos de dos registros muestra un mensaje.
   **Registrar** abre el registro de peso (HU-21).
4. **Consumo por día**: una barra por día (calorías, proteína o grasa, a elegir) con la raya de la meta de ese día. La
   barra se ve plena si el día cumplió: en calorías, `goal_met` del backend (90 % a 110 %, HU-11); en proteína y grasa,
   la misma regla aplicada a su meta. En un mes se rotulan solo algunos días. Sin comidas en el periodo, un mensaje.
5. **Entrenamiento**: sesiones completadas contra los días de entrenamiento del perfil, por semana. Sin días de
   entrenamiento, un mensaje.
6. Sin conexión (RNF-11): sin datos previos, el error con **Reintentar**; si ya había un reporte, se conserva y se avisa.

## Contrato (`ProgressResponse`)

Lo arma `backend/src/services/progress.rs` y lo devuelven los dos endpoints (rango de hasta 93 días, `from` ≤ `to`):

- HU-22: `GET /api/v1/users/me/progress?from=YYYY-MM-DD&to=YYYY-MM-DD` (solo rol `user`).
- HU-23: `GET /api/v1/coach/clients/{clientId}/progress?from=&to=` (solo rol `coach`, vinculación activa).

```json
{
  "weights": [{ "id": "…", "user_id": "…", "weight_kg": 73.1, "recorded_at": "2026-10-30T15:00:00Z" }],
  "daily": [
    {
      "date": "2026-10-30",
      "goal": { "source": "system", "totals": { "calories_kcal": 2000, "protein_g": 150, "fat_g": 60 } },
      "consumed": { "calories_kcal": 1900, "protein_g": 140, "fat_g": 55 },
      "remaining": { "calories_kcal": 100, "protein_g": 10, "fat_g": 5 }
    }
  ],
  "compliance": [
    { "start": "2026-10-30", "end": "2026-11-05", "training_days": 3, "completed_sessions": 0 }
  ]
}
```

- `weights` en orden cronológico; `daily` con todos los días del rango (sin registros, consumo en 0).
- La respuesta no trae `from`/`to` ni `goal_met`: `ProgressModel` usa el periodo pedido y calcula el cumplimiento
  de calorías con `withinGoal` (90 %–110 %, la misma regla que `goal_met` de HU-11).
- `compliance`: `training_days` = sesiones planeadas de la semana (días de entrenamiento del perfil; 3 sin perfil).
  Hoy el backend devuelve `completed_sessions` siempre en 0.
- Errores: `400 VALIDATION_ERROR` (fechas, `from` > `to` o más de 93 días), `401`, `403 FORBIDDEN_ROLE` y, en HU-23,
  `403 CLIENT_NOT_LINKED`.
- `ProgressModel` también acepta las claves del contrato provisional que usó HU-22 antes de publicarse la API
  (`from`, `to`, `days`, meta plana o `null`, `goal_met`, `week_start`, `week_end`, `planned_sessions`).
