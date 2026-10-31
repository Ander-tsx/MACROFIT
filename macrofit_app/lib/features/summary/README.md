# `features/summary/` — resúmenes de consumo

Consumo del usuario comparado con su meta. HU-10 (resumen del día, `GET /users/me/summary/daily`) se muestra en la
pantalla principal (`features/home`); HU-11 (resumen semanal, `GET /users/me/summary/weekly`) tiene su propia pantalla.

| Archivo | Contenido |
|---|---|
| `domain/entities/macro_values.dart` | `MacroValues`: calorías (kcal), proteína (g) y grasa (g) |
| `domain/entities/day_summary.dart` | `DaySummary`: día, origen de la meta, meta, consumo y restante (negativo si se pasó) |
| `domain/entities/week_summary.dart` | `WeekSummary` (HU-11): primer y último día, 7 `DaySummary`, promedio y `goalMetDays` |
| `domain/repositories/summary_repository.dart` | Contrato `SummaryRepository`: `getDaily(date)` y `getWeekly(start)` |
| `domain/usecases/app_day.dart` | `appDay(now)`: día `YYYY-MM-DD` en la zona de la app (`UTC-6`, igual que `APP_UTC_OFFSET` del backend); `shiftDay`, `weekdayOf`, `dayOfMonth`, `monthOf` para trabajar con días de ese formato |
| `data/models/day_summary_model.dart` | JSON de la API → entidad (los números llegan como `int` o `double`) |
| `data/datasources/summary_remote_data_source.dart` | `GET /users/me/summary/daily?date=` y `GET /users/me/summary/weekly?start=` con el cliente con sesión |
| `data/models/week_summary_model.dart` | JSON del resumen semanal → entidad |
| `data/repositories/summary_repository_impl.dart` | Implementa el contrato |
| `presentation/weekly_summary/weekly_summary_view_model.dart` | HU-11: semana que se ve (`start`/`end`), `load`, `previousWeek`, `nextWeek`, `canGoForward` |
| `presentation/weekly_summary/weekly_summary_view.dart` | `/user/summary`: selector de semana, gráfica, promedio y días cumplidos, detalle por día |
| `presentation/weekly_summary/weekly_calories_chart.dart` | Gráfica de barras (sin paquetes): consumido por día contra la raya de la meta de ese día |
| `presentation/weekly_summary/weekly_summary_texts.dart` | Textos de fechas (`lun`, `16 oct`, `16 oct – 22 oct`) y números |

## Decisiones

- El día se calcula en `UTC-6` desde la hora del dispositivo convertida a UTC, así que no depende de la zona del
  teléfono: es el mismo criterio con el que el backend agrupa los registros (`GET /meals?date=`). Si el backend cambia
  `APP_UTC_OFFSET`, hay que cambiar `appUtcOffset`.
- Los valores se muestran sin decimales sobrantes (`70`, `1050.5`); la API los redondea a 1 decimal.

## Resumen semanal (HU-11)

1. El botón de barras del inicio abre `/user/summary` (subruta de `/user`) y se consulta `GET /users/me/summary/weekly?start=`
   con la semana que **termina hoy** (`start` = hoy − 6 días, hora de México).
2. La gráfica dibuja una barra por día (lo consumido) y una raya con la meta de **ese** día (la meta puede cambiar a mitad de
   semana). Un día sin registros aparece en 0. Sobre cada barra va ✓ (cumplida) o ✗ (no cumplida) según `goal_met`
   (90 %–110 % de la meta de calorías), y la lista de abajo lo repite con texto: no depende solo del color.
3. Se muestran el promedio diario de calorías, proteína y grasa y *Días con la meta cumplida: N de 7* (`goal_met_days`).
4. **‹** va a la semana anterior y **›** a la siguiente; esta última se desactiva cuando la semana ya termina hoy. Al cambiar
   de semana se quita la anterior mientras carga (no se ve bajo otras fechas) y se descarta la respuesta de una semana que ya
   no se ve.
5. `404 PROFILE_NOT_FOUND` muestra un mensaje, no un error. Otro error (p. ej. sin conexión) muestra el mensaje con
   **Reintentar**; si falla una recarga de la misma semana se conserva el resumen. Deslizar hacia abajo vuelve a consultar.

## Decisiones

- **Sin paquete de gráficas.** La historia pedía un paquete «aprobado en el PR de andamiaje», pero no hay ninguno aprobado ni
  en `pubspec.yaml` (AGENTS.md §2: no se agregan paquetes sin preguntar). La gráfica son 7 barras con widgets de Flutter; si
  el equipo prefiere `fl_chart` u otro, se cambia solo `weekly_calories_chart.dart`.
- La gráfica muestra calorías (RF-10); proteína y grasa entran como promedio.
