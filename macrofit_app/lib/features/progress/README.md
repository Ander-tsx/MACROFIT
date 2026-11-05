# `features/progress/` — peso y progreso del usuario

| Historia | Qué hace |
|---|---|
| HU-21 | Registro e historial de peso (`/user/weights`) |
| HU-22 | "Mi progreso" (`/user/progress`, pestaña **Progreso** de la barra inferior): gráficas de peso, consumo por día contra la meta y cumplimiento de entrenamiento, por semana o por mes (RF-18) |

## Archivos

| Archivo | Contenido |
|---|---|
| `domain/entities/weight_entry.dart` | Registro de peso (HU-21) |
| `domain/entities/progress_report.dart` | `ProgressReport` (HU-22): `weights`, `days` (consumo contra la meta de cada día) y `compliance` (sesiones por semana), con `hasWeightTrend`, `hasMeals` y `hasCompliance` |
| `domain/entities/progress_period.dart` | `ProgressPeriod` y `ProgressRange` (semana / mes): periodo actual, anterior y siguiente sin pasar de hoy |
| `domain/repositories/` | `WeightsRepository` (HU-21) y `ProgressRepository` (HU-22) |
| `data/datasources/progress_remote_data_source.dart` | `GET /users/me/progress?from=&to=` con el cliente con sesión |
| `data/models/progress_model.dart` | JSON → `ProgressReport` (`goal: null` = día sin meta todavía; listas ausentes = vacías) |
| `presentation/weights/` | Pantalla y ViewModel del registro de peso (HU-21) |
| `presentation/progress_charts/progress_view_model.dart` | `ProgressViewModel`: periodo, reporte, carga, error, macro elegido; descarta respuestas de un periodo que ya no se ve |
| `presentation/progress_charts/progress_view.dart` | Selector semana/mes, píldora del periodo y tres tarjetas: **Peso**, **Consumo por día** y **Entrenamiento** |
| `presentation/progress_charts/progress_texts.dart` | Etiquetas de periodo y ejes, cambio de peso y regla "dentro de la meta" para proteína y grasa |

Las gráficas son widgets **sin estado** de `core/presentation/widgets/charts/` (`TrendLineChart`, `TargetBarChart`,
`RatioBars`) que reciben sus datos por parámetro: HU-23-APP (progreso del cliente para el coach) las reutiliza sin
modificarlas, convirtiendo sus entidades a `ChartPoint`, `TargetBar` y `RatioItem`.

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

## Contrato de `GET /users/me/progress` (provisional)

> HU-22-API todavía no está publicada. La app sigue el contrato descrito en su tarjeta de Praxis; cuando el endpoint se
> documente en `backend/README.md` hay que revisar esta sección y `ProgressModel`.

`GET /api/v1/users/me/progress?from=YYYY-MM-DD&to=YYYY-MM-DD` (solo rol `user`, rango de hasta 93 días).

```json
{
  "from": "2026-10-30",
  "to": "2026-11-05",
  "weights": [{ "weight_kg": 73.1, "recorded_at": "2026-10-30T15:00:00Z" }],
  "days": [
    {
      "date": "2026-10-30",
      "goal": { "source": "system", "calories_kcal": 2000, "protein_g": 150, "fat_g": 60 },
      "consumed": { "calories_kcal": 1900, "protein_g": 140, "fat_g": 55 },
      "goal_met": true
    }
  ],
  "compliance": [
    { "week_start": "2026-10-30", "week_end": "2026-11-05", "completed_sessions": 2, "planned_sessions": 4 }
  ]
}
```

- `weights` en orden cronológico; `days` con todos los días del rango (los días sin registros con consumo en 0).
- `compliance`: sesiones completadas (`routine_sessions`, HU-17) contra los días de entrenamiento del perfil.
- Errores: `400 VALIDATION_ERROR` (fechas mal formadas, `from` > `to` o más de 93 días), `401`, `403 FORBIDDEN_ROLE`.
