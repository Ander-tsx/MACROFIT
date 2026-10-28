# `features/home/` — pantallas principales por rol

Pantallas a las que el router lleva tras iniciar sesión (HU-02). La del usuario muestra su meta vigente (HU-26); la del
coach todavía es provisional.

| Archivo | Contenido |
|---|---|
| `presentation/user_home_view.dart` | `/user` — rol `user`. Meta vigente (HU-26) con «deslizar para actualizar» , botón **Mi perfil** (`/user/profile`, HU-03) y botón flotante **Registrar comida** (`/user/meals/photo`, HU-06). Se llenará con HU-10 (resumen diario), etc. |
| `presentation/user_home_view_model.dart` | `UserHomeViewModel extends HomeViewModel`: sesión + `loadGoal()` (`GoalsRepository` del dominio de `goals`) |
| `presentation/coach_home_view.dart` | `/coach` — rol `coach`. Botón **Mi código de invitación** (`/coach/invite-code`, HU-12; en el cuerpo y en la barra), **Mis clientes** (`/coach/clients`, HU-24) y **Mis rutinas** (`/coach/routines`, HU-18; en el cuerpo y en la barra). |
| `presentation/home_view_model.dart` | Usuario actual y `logout()` (usa el `AuthRepository` del dominio de `auth`) |
| `presentation/widgets/home_scaffold.dart` | Barra con el botón **Cerrar sesión** (con confirmación) común a ambas |
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
