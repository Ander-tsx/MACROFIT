# `features/goals/` — metas nutricionales

## Historias

- **HU-04** (backend): la meta del usuario se calcula en el servidor. La app solo conserva el dominio del cálculo
  (`usecases/`), sin pantallas hasta HU-26.
- **HU-05**: "Como coach, quiero definir y ajustar las metas de calorías y macros de cada cliente para personalizar su plan."

## Archivos

| Capa | Archivo | Contenido |
|---|---|---|
| Dominio | `entities/nutritional_goal.dart` | `NutritionalGoal` y `GoalSource` (`system` / `coach`) |
| | `entities/coach_client.dart` | `CoachClient` (id, nombre, correo) |
| | `repositories/goals_repository.dart` | Meta vigente e historial del usuario (HU-04) |
| | `repositories/coach_goals_repository.dart` | `getClients` / `getClientGoals` / `setClientGoal` (HU-05) |
| | `validators/coach_goal_validators.dart` | Mismas reglas que `backend/src/services/goals.rs` |
| Datos | `datasources/goals_remote_datasource.dart` | Endpoints de metas con el cliente **con sesión** |
| | `models/goal_model.dart`, `models/coach_client_model.dart` | JSON de la API |
| | `repositories/goals_repository_impl.dart` | `GoalsRepositoryImpl` y `CoachGoalsRepositoryImpl` |
| Presentación | `coach_clients/` | Lista mínima de clientes vinculados |
| | `coach_goal_form/` | Formulario de meta (calorías, proteína, grasa, vigencia) e historial del cliente |

## Flujo del coach (HU-05)

1. En `/coach`, el botón **Mis clientes** abre `/coach/clients` (`GET /coach/clients`).
2. Al elegir un cliente se abre `/coach/clients/:clientId/goals` pasando el `CoachClient` como `extra`
   (sin él, la ruta vuelve a la lista). Son 2 pantallas desde la principal.
3. La pantalla carga el historial (`GET .../goals`) y valida el formulario antes de enviar; los errores del backend con
   `fields` se muestran en su campo y `CLIENT_NOT_LINKED` como error general.
4. `POST .../goals` agrega la meta al historial y la pantalla lo recarga. La fecha de vigencia empieza en hoy.

## Decisiones

- Nombres de campos del formulario = nombres de la API (`calories`, `protein_g`, `fat_g`, `effective_from`).
- `TODO(HU-24)`: la lista de clientes completa reemplaza a la mínima de HU-05.
- `TODO(HU-26)`: las pantallas del usuario (meta vigente e historial) usarán `GoalsRepository`, que todavía no se registra
  en `dependencies.dart`.
- `carbsG` no existe en la API (siempre llega como 0); queda pendiente decidir en HU-10 si se calcula o se elimina.
