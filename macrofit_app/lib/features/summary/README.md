# `features/summary/` — resúmenes de consumo

Consumo del usuario comparado con su meta. HU-10 (resumen del día, `GET /users/me/summary/daily`) se muestra en la
pantalla principal (`features/home`); HU-11 agregará el resumen semanal.

| Archivo | Contenido |
|---|---|
| `domain/entities/macro_values.dart` | `MacroValues`: calorías (kcal), proteína (g) y grasa (g) |
| `domain/entities/day_summary.dart` | `DaySummary`: día, origen de la meta, meta, consumo y restante (negativo si se pasó) |
| `domain/repositories/summary_repository.dart` | Contrato `SummaryRepository.getDaily(date)` |
| `domain/usecases/app_day.dart` | `appDay(now)`: día `YYYY-MM-DD` en la zona de la app (`UTC-6`, igual que `APP_UTC_OFFSET` del backend) |
| `data/models/day_summary_model.dart` | JSON de la API → entidad (los números llegan como `int` o `double`) |
| `data/datasources/summary_remote_data_source.dart` | `GET /users/me/summary/daily?date=` con el cliente con sesión |
| `data/repositories/summary_repository_impl.dart` | Implementa el contrato |

## Decisiones

- El día se calcula en `UTC-6` desde la hora del dispositivo convertida a UTC, así que no depende de la zona del
  teléfono: es el mismo criterio con el que el backend agrupa los registros (`GET /meals?date=`). Si el backend cambia
  `APP_UTC_OFFSET`, hay que cambiar `appUtcOffset`.
- Los valores se muestran sin decimales sobrantes (`70`, `1050.5`); la API los redondea a 1 decimal.
