# `features/home/` — pantallas principales por rol

Pantallas a las que el router lleva tras iniciar sesión (HU-02). La del usuario muestra su progreso del día (HU-10) y su meta vigente (HU-26); la del
coach todavía es provisional.

| Archivo | Contenido |
|---|---|
| `presentation/user_home_view.dart` | `/user` — rol `user`. Meta vigente (HU-26) con «deslizar para actualizar» , botón **Mi perfil** (`/user/profile`, HU-03) y botón flotante **Registrar comida** (`/user/meals/photo`, HU-06). Progreso del día (HU-10) sobre la meta. |
| `presentation/user_home_view_model.dart` | `UserHomeViewModel extends HomeViewModel`: sesión + `loadGoal()` (`GoalsRepository` del dominio de `goals`) + `loadSummary()` (`SummaryRepository` del dominio de `summary`); `refresh()` hace ambas |
| `presentation/coach_home_view.dart` | `/coach` — rol `coach`. Botón **Mi código de invitación** (`/coach/invite-code`, HU-12; en el cuerpo y en la barra) y **Mis clientes** (`/coach/clients`, HU-24). |
| `presentation/home_view_model.dart` | Usuario actual y `logout()` (usa el `AuthRepository` del dominio de `auth`) |
| `presentation/widgets/home_scaffold.dart` | Barra con el botón **Cerrar sesión** (con confirmación) común a ambas |
| (`user_home_view.dart`, HU-11) | Botón de barras de la barra superior (`weekly_summary_button`, **Resumen semanal**) que abre `/user/summary` (`features/summary`) |
| `presentation/widgets/daily_progress_card.dart` | Tarjeta del progreso del día (HU-10): una barra por calorías, proteína y grasa con consumido / meta y lo que falta o el exceso |
| `presentation/widgets/current_goal_card.dart` | Tarjeta de la meta: calorías, proteína, grasa y origen («Calculada» / «Definida por tu coach») |
| `presentation/widgets/welcome_message.dart` | Contenido provisional (coach) |

- No tiene capas de datos ni dominio propias todavía; cuando una historia necesite datos de inicio, se agregan aquí
  siguiendo la plantilla de `lib/features/README.md`.
- HU-03: un usuario con `profileCompleted == false` va primero al formulario de perfil; la regla vive en
  `resolveRedirect` (`lib/app/router.dart`), no en estas vistas.
- `HomeScaffold<T extends HomeViewModel>` lee el ViewModel de la ruta (`HomeViewModel` por omisión, `UserHomeViewModel`
  en la del usuario).
- `HomeScaffold` acepta `actions` extra para la barra (p. ej. **Mi perfil**), antes del botón de cerrar sesión, y un
  `floatingActionButton` opcional (p. ej. **Registrar comida**).

## Meta vigente (HU-26)

1. Al entrar a `/user` se consulta `GET /users/me/goals/current` (`loadGoal()` al crear el ViewModel).
2. La tarjeta muestra calorías, proteína y grasa, y el origen según `source` (RN-06: la del coach prevalece).
3. `404 PROFILE_NOT_FOUND` (sin perfil ni meta del coach) muestra un mensaje, no un error. Otro error (p. ej. sin
   conexión) muestra el mensaje con **Reintentar**; si ya había una meta cargada, se conserva.
4. Al regresar de **Mi perfil** y al deslizar hacia abajo se consulta de nuevo, para reflejar el recálculo de HU-04.

## Progreso del día (HU-10)

1. Al entrar a `/user` se consulta `GET /users/me/summary/daily?date=` con el día de hoy en hora de México (`appDay`).
2. La tarjeta muestra una barra por calorías, proteína y grasa con `consumido / meta` y *Te faltan X*. Si el restante es
   negativo la barra queda llena, en color de error, y dice *Te pasaste por X*. Un día sin registros muestra consumo en 0.
3. `404 PROFILE_NOT_FOUND` muestra un mensaje, no un error. Otro error (p. ej. sin conexión) muestra el mensaje con
   **Reintentar**; si ya había un resumen cargado, se conserva.
4. Se vuelve a consultar al regresar de **Registrar comida** y de **Mi perfil**, y al deslizar hacia abajo.
