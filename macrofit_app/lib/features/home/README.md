# `features/home/` — pantallas principales por rol

Pantallas a las que el router lleva tras iniciar sesión (HU-02). La del usuario muestra su progreso del día (HU-10) y su meta vigente (HU-26); la del
coach, accesos a su código, rutinas y clientes. Ambas usan la guía visual (TEC-17): saludo con el primer nombre y el avatar, y tarjetas. La barra inferior es global
(`lib/app/navigation/app_dock.dart`) y está en todas las pantallas del rol.

| Archivo | Contenido |
|---|---|
| `presentation/user_home_view.dart` | `/user` — rol `user`. Meta vigente (HU-26) con «deslizar para actualizar» , botón **Mi perfil** (`/user/profile`, HU-03) y botón flotante **Registrar comida** (`/user/meals/photo`, HU-06) y **Mis comidas** (`/user/meals`, HU-09) y la tarjeta **Mis rutinas** (`/user/routines`, HU-16). Progreso del día (HU-10) sobre la meta. Al regresar al inicio desde cualquier pantalla (`RefreshOnReturn`) se vuelven a consultar la meta y el progreso: guardar una comida abre "Mis comidas" con `go` y atrás regresa aquí. |
| `presentation/widgets/refresh_on_return.dart` | `RefreshOnReturn`: escucha al router y llama a `onReturn` cuando su ruta vuelve a quedar arriba, venga de un `pop` o de un `go` |
| `presentation/user_home_view_model.dart` | `UserHomeViewModel extends HomeViewModel`: sesión + `loadGoal()` (`GoalsRepository` del dominio de `goals`) + `loadSummary()` (`SummaryRepository` del dominio de `summary`); `refresh()` hace ambas |
| `presentation/coach_home_view.dart` | `/coach` — rol `coach`. Botón **Mi código de invitación** (`/coach/invite-code`, HU-12; en el cuerpo y en la barra), **Mis clientes** (`/coach/clients`, HU-24) y **Mis rutinas** (`/coach/routines`, HU-18; en el cuerpo y en la barra). |
| `presentation/home_view_model.dart` | Usuario actual y `logout()` (usa el `AuthRepository` del dominio de `auth`) |
| `presentation/widgets/home_scaffold.dart` | Saludo, avatar Blobatar del correo (en el usuario abre **Mi perfil**, `profile_button`; en el coach, la hoja de su cuenta, `account_button`), contenido y barra inferior; común a ambas |
| `presentation/widgets/account_sheet.dart` | Hoja de la cuenta del coach: avatar, nombre, correo, rol y **Cerrar sesión** (`logout_button`, con confirmación `logout_confirm`) |
| `presentation/widgets/daily_progress_card.dart` | Tarjeta del progreso del día (HU-10): anillos concéntricos de los tres macros; por macro, consumido / meta y lo que falta o el exceso; barra de calorías |
| `presentation/widgets/current_goal_card.dart` | Tarjeta de la meta: calorías, proteína, grasa y origen («Calculada» / «Definida por tu coach») |
| (barra inferior) | Ya no vive aquí: es global (`AppDock`, `lib/app/navigation`, ver `lib/app/README.md`). Claves: `home_tab`, `meal_history_button`, `weekly_summary_button`, `progress_button` (HU-22), `register_meal_button` (usuario) y `clients_button`, `routines_button`, `invite_code_button` (coach) |

- No tiene capas de datos ni dominio propias todavía; cuando una historia necesite datos de inicio, se agregan aquí
  siguiendo la plantilla de `lib/features/README.md`.
- HU-03: un usuario con `profileCompleted == false` va primero al formulario de perfil; la regla vive en
  `resolveRedirect` (`lib/app/router.dart`), no en estas vistas.
- `HomeScaffold<T extends HomeViewModel>` lee el ViewModel de la ruta (`HomeViewModel` por omisión, `UserHomeViewModel`
  en la del usuario).
- `HomeScaffold` recibe el subtítulo, el contenido, la acción del avatar y la barra inferior (`HomeDock`).
- El registro de peso (HU-21, `/user/weights`) se abre desde **Registrar** en "Mi progreso" (HU-22, pestaña **Progreso**).
- **Cerrar sesión** (HU-02) ya no está en el inicio: el usuario lo encuentra al final de **Mi perfil** y el coach en la
  hoja de su cuenta (al tocar su avatar). Ambos piden confirmación.

## Meta vigente (HU-26)

1. Al entrar a `/user` se consulta `GET /users/me/goals/current` (`loadGoal()` al crear el ViewModel).
2. La tarjeta muestra calorías, proteína y grasa, y el origen según `source` (RN-06: la del coach prevalece).
3. `404 PROFILE_NOT_FOUND` (sin perfil ni meta del coach) muestra un mensaje, no un error. Otro error (p. ej. sin
   conexión) muestra el mensaje con **Reintentar**; si ya había una meta cargada, se conserva.
4. Al regresar de **Mi perfil** y al deslizar hacia abajo se consulta de nuevo, para reflejar el recálculo de HU-04.

## Progreso del día (HU-10)

1. Al entrar a `/user` se consulta `GET /users/me/summary/daily?date=` con el día de hoy en hora de México (`appDay`).
2. La tarjeta muestra una barra por calorías, proteína y grasa con `consumido / meta` y *Te faltan X*. Si el restante es
   negativo la barra queda llena, en color de advertencia, y dice *Te pasaste por X*. Un día sin registros muestra consumo en 0.
3. `404 PROFILE_NOT_FOUND` muestra un mensaje, no un error. Otro error (p. ej. sin conexión) muestra el mensaje con
   **Reintentar**; si ya había un resumen cargado, se conserva.
4. Se vuelve a consultar al regresar de **Registrar comida** y de **Mi perfil**, y al deslizar hacia abajo.
