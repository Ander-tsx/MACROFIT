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
- Pendientes de otra historia: `// TODO(ID): qué falta y qué hay que cambiar` (ver el TODO de TEC-07 en `auth.rs`).

## Archivos

| Archivo | Contenido |
|---|---|
| `auth.rs` | `validate_registration`, `register` (HU-01), `login` (HU-02, con hash ficticio para igualar tiempos), `find_user_by_id` |
| `session.rs` | HU-02: `start` (login), `refresh` (rotación atómica + detección de reuso), `logout`, `is_active` |

### Pendiente conocido

- **TEC-07 — aviso de privacidad**: `validate_registration` aún acepta `privacy_accepted: false`.
  Al implementarlo: devolver `AppError::PrivacyNotAccepted`, actualizar el test `sin_aviso_de_privacidad_aun_se_acepta`
  y el request `HU-01 Registro / Sin aviso de privacidad` de `postman/auth/auth.postman_collection.json` (luego `node postman/build.js`) para que espere `400`.
