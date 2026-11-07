# `features/my_routines/` — rutinas del usuario (HU-16) y sesiones completadas (HU-17)

**HU-16-APP:** "Como usuario, quiero ver mis rutinas identificando si son recomendadas o asignadas para saber cuál
seguir." (RF-15, RF-23, RN-08, RNF-11). El usuario ve su rutina recomendada (HU-15) y las que le asignó su coach
(HU-19), cada una con su origen; abre una para ver sus sesiones con ejercicios, series, repeticiones y descanso.

**HU-17-APP:** "Como usuario, quiero marcar una sesión como completada para registrar mi cumplimiento." (RF-16,
RNF-11). En el detalle, cada sesión tiene **Marcar completada** (con confirmación); las completadas hoy se
muestran marcadas con su fecha y no se pueden registrar dos veces.

## Endpoints

Cliente HTTP **con** sesión; solo rol `user`.

| Endpoint | Uso | Estado |
|---|---|---|
| `GET /users/me/routines` | Lista «Mis rutinas» | Contrato propuesto para HU-16-API (abajo) |
| `GET /routines/{id}` | Detalle | Contrato propuesto para HU-16-API (abajo) |
| `POST /users/me/routines/recommended` | Acceso desde la lista vacía: genera la recomendada y abre su detalle | HU-15-API, en develop |
| `GET /users/me/routines/{id}/sessions` | HU-17: sesiones completadas de la rutina (se marcan las de hoy) | HU-17-API (PR #67) |
| `POST /users/me/routines/{id}/sessions` | HU-17: `{ session_number }`; sin `date`, la API registra hoy (hora de México) | HU-17-API (PR #67) |

### Contrato que usa la app (HU-16-API)

HU-16-API se acopla a esta forma (la misma de HU-15 para el detalle; una rutina del coach es **una sola sesión, la 1,
con el nombre de la rutina**, igual que en HU-17-API):

```json
// GET /users/me/routines → 200 (recomendada vigente primero, luego asignadas activas; [] sin rutinas)
[
  { "id": "6b2a...", "origin": "system", "name": "Rutina recomendada · Mantener · 3 días", "coach_name": null, "session_count": 3 },
  { "id": "6b01...", "origin": "coach",  "name": "Torso A", "coach_name": "Carlos", "session_count": 1 }
]

// GET /routines/{id} → 200
{
  "id": "6b01...", "origin": "coach", "name": "Torso A", "coach_name": "Carlos",
  "sessions": [
    { "number": 1, "name": "Torso A",
      "exercises": [ { "exercise_id": "6ac6...", "name": "Press de banca", "muscle_group": "chest",
                       "sets": 4, "reps": 10, "rest_seconds": 90 } ] }
  ]
}
```

Errores: `404 ROUTINE_NOT_FOUND` (ajena, retirada, reemplazada, inexistente o id mal formado), `401`, `403 FORBIDDEN_ROLE`.
Campos extra (p. ej. `focus`, `equipment`, `level`) se ignoran.

## Archivos

| Archivo | Contenido |
|---|---|
| `domain/entities/user_routine.dart` | `RoutineOrigin` (`system` / `coach`), `UserRoutineSummary` (lista), `UserRoutine`, `RoutineSessionPlan`, `SessionExercise` |
| `domain/entities/completed_session.dart` | `CompletedSession` (HU-17): número y nombre de la sesión, día `YYYY-MM-DD` y hora del registro |
| `domain/repositories/my_routines_repository.dart` | Contrato `MyRoutinesRepository` (`getRoutines`, `getRoutine`, `requestRecommendedRoutine`; HU-17: `getCompletedSessions`, `completeSession`) |
| `data/models/user_routine_model.dart` | JSON de la lista y del detalle (también la respuesta de HU-15) |
| `data/models/completed_session_model.dart` | JSON de la sesión completada y cuerpo `{ session_number }` (HU-17) |
| `data/datasources/my_routines_remote_data_source.dart` | Los 5 endpoints con `guardApiCall` |
| `data/repositories/my_routines_repository_impl.dart` | Implementación del contrato |
| `presentation/routines_list/` | `/user/routines` «Mis rutinas»: lista con origen, vacío con acceso a la recomendada, error con «Reintentar» |
| `presentation/routine_detail/` | `/user/routines/:routineId`: sesiones con ejercicios y volumen; `ROUTINE_NOT_FOUND` avisa y regresa. HU-17: botón por sesión, «Completada hoy · fecha», errores por sesión con «Reintentar» |
| `presentation/widgets/` | `OriginTag` (píldora de origen con ícono) y textos (`originLabel`, `sessionCountText`, `exerciseVolumeText`) |

## Flujo

1. **Inicio** → tarjeta **Mis rutinas**. La lista se consulta **al abrir**, **al deslizar hacia abajo** y **al volver del
   detalle**, sin caché: una rutina recién asignada aparece sin reiniciar la app (RF-23).
2. Cada rutina muestra nombre, número de sesiones y su origen: **Recomendada** o **Asignada por <coach>** (RN-08), con
   ícono además del texto.
3. Sin rutinas: mensaje y **Ver recomendada** (pide la de HU-15 y abre su detalle). Sin perfil, explica que
   falta completarlo.
4. El detalle muestra cada sesión (`Día 1 · Cuerpo completo`) con sus ejercicios: grupo muscular, series × reps y
   descanso.
5. Si la rutina ya no está disponible (`404 ROUTINE_NOT_FOUND`, p. ej. el coach la retiró), avisa y regresa a la lista,
   que se recarga. Sin conexión: mensaje en español y **Reintentar**; la app sigue funcionando (RNF-11).
6. **HU-17:** al abrir el detalle se consultan las sesiones completadas; las de **hoy** (día en hora de México, igual
   que la API) muestran «Completada hoy · 7 de noviembre» en lugar del botón. **Marcar completada** pide
   confirmación y envía `POST` con el número de la sesión.
   - `409 SESSION_ALREADY_COMPLETED` (p. ej. se registró en otro dispositivo): avisa «Ya registraste esta sesión hoy» y
     la marca.
   - `404 ROUTINE_NOT_FOUND`: avisa que la rutina ya no está disponible y regresa a la lista.
   - Sin conexión: el registro no se pierde en silencio; la sesión muestra el error y su botón cambia a **Reintentar**.
   - Si no se pudieron consultar las completadas, la rutina se muestra igual con un aviso.

## Decisiones

- Feature propia (`my_routines`) separada de `routines` (coach): solo comparte el concepto, no código.
- El acceso desde la lista vacía usa directamente `POST /users/me/routines/recommended` (HU-15-API ya existe) en lugar de
  una pantalla aparte; HU-15-APP puede reemplazar esa navegación si agrega la suya.
