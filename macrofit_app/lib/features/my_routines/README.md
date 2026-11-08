# `features/my_routines/` — rutinas del usuario (HU-16)

**HU-16-APP:** "Como usuario, quiero ver mis rutinas identificando si son recomendadas o asignadas para saber cuál
seguir." (RF-15, RF-23, RN-08, RNF-11). El usuario ve su rutina recomendada (HU-15) y las que le asignó su coach
(HU-19), cada una con su origen; abre una para ver sus sesiones con ejercicios, series, repeticiones y descanso.

## Endpoints

Cliente HTTP **con** sesión; solo rol `user`.

| Endpoint | Uso | Estado |
|---|---|---|
| `GET /users/me/routines` | Lista «Mis rutinas» | Contrato propuesto para HU-16-API (abajo) |
| `GET /routines/{id}` | Detalle | Contrato propuesto para HU-16-API (abajo) |
| `POST /users/me/routines/recommended` | Acceso desde la lista vacía: genera la recomendada y abre su detalle | HU-15-API, en develop |

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
| `domain/repositories/my_routines_repository.dart` | Contrato `MyRoutinesRepository` (`getRoutines`, `getRoutine`, `requestRecommendedRoutine`) |
| `data/models/user_routine_model.dart` | JSON de la lista y del detalle (también la respuesta de HU-15) |
| `data/datasources/my_routines_remote_data_source.dart` | Los 3 endpoints con `guardApiCall` |
| `data/repositories/my_routines_repository_impl.dart` | Implementación del contrato |
| `presentation/routines_list/` | `/user/routines` «Mis rutinas»: lista con origen, vacío con acceso a la recomendada, error con «Reintentar» |
| `presentation/routine_detail/` | `/user/routines/:routineId`: sesiones con ejercicios y volumen; `ROUTINE_NOT_FOUND` avisa y regresa |
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

## Decisiones

- Feature propia (`my_routines`) separada de `routines` (coach): solo comparte el concepto, no código.
- El acceso desde la lista vacía usa directamente `POST /users/me/routines/recommended` (HU-15-API ya existe) en lugar de
  una pantalla aparte; HU-15-APP puede reemplazar esa navegación si agrega la suya.
