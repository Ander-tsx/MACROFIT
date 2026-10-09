# `src/models/` — documentos de MongoDB

Un archivo por colección. Cada archivo define la constante con el nombre de la colección
(`pub const USERS_COLLECTION: &str = "users";`) y el struct que se guarda.

## Reglas

- Campos en `snake_case` (así quedan en Mongo).
- `_id` como `#[serde(rename = "_id", skip_serializing_if = "Option::is_none")] pub id: Option<ObjectId>`.
- Fechas con `mongodb::bson::DateTime` (se guardan como `ISODate`), no como texto.
- Enumeraciones con `#[serde(rename_all = "lowercase")]`.
- Los modelos **no se devuelven al cliente**: cada ruta tiene su DTO de respuesta.
- Los índices se declaran en `src/db.rs::ensure_indexes` y se documentan aquí.
- Cambiar un campo existente implica migrar los documentos ya guardados: anótalo en el PR.

## Colección `users` (`user.rs`)

| Campo | Tipo | Notas |
|---|---|---|
| `_id` | ObjectId | Se expone como `id` (hex) |
| `name` | string | Sin espacios alrededor |
| `email` | string | Normalizado: minúsculas y sin espacios |
| `password_hash` | string | Argon2id en formato PHC (`$argon2id$...`). Nunca se guarda la contraseña |
| `role` | `"user"` \| `"coach"` | |
| `privacy_accepted_at` | ISODate \| null | Momento de aceptación del aviso. `null` solo en cuentas anteriores a TEC-07 |
| `privacy_version` | string \| ausente | Versión del aviso aceptada (p. ej. `"1.0"`). Ausente en cuentas anteriores a TEC-07 |
| `profile_completed` | bool | `false` al registrarse; `true` al crear el perfil (HU-03) |
| `created_at` | ISODate | |

**Índices:** `email_unique` → `{ email: 1 }`, único. Como el correo se guarda normalizado,
también impide duplicados que solo difieren en mayúsculas.

## Colección `refresh_tokens` (`refresh_token.rs`)

Un documento por refresh token emitido (HU-02). Los tokens de un mismo login comparten `session_id`.

| Campo | Tipo | Notas |
|---|---|---|
| `_id` | ObjectId | |
| `user_id` | ObjectId | Referencia a `users._id` |
| `session_id` | ObjectId | Igual al claim `sid` del access token |
| `token_hash` | string | SHA-256 (hex) del token. El token en claro nunca se guarda |
| `expires_at` | ISODate | Creación + `REFRESH_TOKEN_DAYS` |
| `revoked_at` | ISODate \| null | Se llena al rotar, al cerrar sesión o al detectar reuso |
| `created_at` | ISODate | |

**Índices:** `token_hash_unique` (único), `session_id` y `expires_at_ttl` (TTL con `expireAfterSeconds: 0`:
Mongo borra cada documento cuando pasa su `expires_at`).

## Colección `profiles` (`profile.rs`)

Perfil inicial del usuario (HU-03). Un documento por cuenta con rol `user`.

| Campo | Tipo | Notas |
|---|---|---|
| `_id` | ObjectId | Se expone como `id` (hex) |
| `user_id` | ObjectId | Referencia a `users._id` |
| `objective` | `"lose_fat"` \| `"maintain"` \| `"gain_muscle"` | |
| `level` | `"beginner"` \| `"intermediate"` \| `"advanced"` | |
| `training_days` | int | 1 a 7 |
| `weight_kg` | double | 30 a 300 (provisional, TEC-12) |
| `height_cm` | double | 100 a 250 (provisional, TEC-12) |
| `gender` | `"male"` \| `"female"` | |
| `birth_date` | ISODate | Medianoche UTC; la API la expone como `YYYY-MM-DD` |
| `created_at` | ISODate | |
| `updated_at` | ISODate | Cambia en cada edición |

**Índices:** `user_id_unique` → `{ user_id: 1 }`, único (garantiza un perfil por usuario; el error `11000` se traduce
a `409 PROFILE_ALREADY_EXISTS`).
