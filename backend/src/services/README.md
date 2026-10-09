# `src/services/` — lógica de negocio

Un archivo por dominio (`auth.rs`, y después `profile.rs`, `goals.rs`, ...). Aquí vive lo que hace cada historia.

## Reglas

- Las funciones reciben `&Database` y datos de entrada propios del servicio (p. ej. `RegisterInput`),
  **no** DTOs ni tipos de Axum. Devuelven `Result<Modelo, AppError>`.
- **Validación separada de la persistencia**: una función pura `validate_xxx(input) -> Result<ValidXxx, AppError>`
  que acumula todos los errores en un `FieldErrors` y una función async que la llama y luego toca Mongo.
  Así la validación se prueba sin base de datos.
- **Unicidad**: el índice único de Mongo es la garantía. Se puede hacer una consulta previa para responder rápido,
  pero el error de clave duplicada (código `11000`) también debe traducirse al `AppError` correspondiente.
- **CPU pesada** (hash/verificación de contraseñas) dentro de `tokio::task::spawn_blocking`.
- Mensajes de error al usuario en español, en `FieldErrors` por campo.
- Pendientes de otra historia: `// TODO(ID): qué falta y qué hay que cambiar` .

## Archivos

| Archivo | Contenido |
|---|---|
| `auth.rs` | `validate_registration`, `register` (HU-01), `login` (HU-02, con hash ficticio para igualar tiempos), `find_user_by_id` |
| `legal.rs` | TEC-07: `PRIVACY_NOTICE` (Markdown embebido desde `docs/legal/`) y `PRIVACY_VERSION` (leída de su cabecera) |
| `session.rs` | HU-02: `start` (login), `refresh` (rotación atómica + detección de reuso), `logout`, `is_active` |
| `profile.rs` | HU-03: `validate_new_profile` / `validate_profile_changes` (puras), `create_profile` (marca `profile_completed`), `get_profile`, `update_profile`; rangos provisionales (TEC-12) |

### Aviso de privacidad en el registro

`validate_registration` exige `privacy_accepted: true`. Si es lo único que falla responde `PRIVACY_NOT_ACCEPTED`; si hay
otros campos inválidos lo agrega a `FieldErrors` dentro de `VALIDATION_ERROR`. `register` guarda `privacy_accepted_at`
y `privacy_version`.

### Perfil (HU-03)

- `create_profile` valida, inserta y pone `users.profile_completed = true`. Si el perfil ya existía (consulta previa o
  error `11000`) responde `PROFILE_ALREADY_EXISTS` y **también** asegura la marca en `users`, por si una petición
  anterior guardó el perfil pero no alcanzó a marcar la cuenta.
- `update_profile` solo toca los campos enviados (`$set` + `updated_at`) con `find_one_and_update`.
  Si cambian peso, objetivo o días (`goals::goal_inputs_changed`) llama a `goals::recalculate_on_profile_change`,
  que respeta la meta de un coach. `create_profile` también la llama para generar la meta inicial (HU-04).
