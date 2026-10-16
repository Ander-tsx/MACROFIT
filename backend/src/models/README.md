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
| `weight_kg` | double | 35 a 250 (TEC-12) |
| `height_cm` | double | 130 a 230 (TEC-12) |
| `gender` | `"male"` \| `"female"` | |
| `birth_date` | ISODate | Medianoche UTC; la API la expone como `YYYY-MM-DD` |
| `created_at` | ISODate | |
| `updated_at` | ISODate | Cambia en cada edición |

**Índices:** `user_id_unique` → `{ user_id: 1 }`, único (garantiza un perfil por usuario; el error `11000` se traduce
a `409 PROFILE_ALREADY_EXISTS`).

## Colección `goals` (`goal.rs`)

Historial de metas nutricionales (HU-04 y HU-05). Solo se insertan documentos; nunca se modifican.

| Campo | Tipo | Notas |
|---|---|---|
| `_id` | ObjectId | Se expone como `id` (hex) |
| `user_id` | ObjectId | Referencia a `users._id` |
| `calories`, `protein_g`, `fat_g` | int | |
| `source` | `"system"` \| `"coach"` | Quién fijó la meta |
| `set_by` | ObjectId \| null | Coach que la fijó (solo `source: "coach"`) |
| `effective_from` | ISODate | Desde cuándo aplica. La vigente es la más reciente con `effective_from <= ahora`, y una de coach gana a una `system` |
| `created_at` | ISODate | |

**Índices:** `user_id_effective_from` → `{ user_id: 1, effective_from: -1 }`.

## Colección `weights` (`weight_entry.rs`)

Historial de peso corporal (HU-21). Solo se insertan documentos; nunca se modifican.

| Campo | Tipo | Notas |
|---|---|---|
| `_id` | ObjectId | Se expone como `id` (hex) |
| `user_id` | ObjectId | Referencia a `users._id` (rol `user`) |
| `weight_kg` | double | 35 a 250 (rango del perfil, TEC-12) |
| `recorded_at` | ISODate | La pone el servidor al registrar |

**Índices:** `user_id_recorded_at` → `{ user_id: 1, recorded_at: -1 }` (historial de un usuario, el más reciente primero).

## Colección `meals` (`meal.rs`)

Registros de comida (HU-09, RF-08). Se insertan con `POST /meals` y se borran con `DELETE /meals/{id}` (junto con su foto).

| Campo | Tipo | Notas |
|---|---|---|
| `_id` | ObjectId | Se expone como `id` (hex) |
| `user_id` | ObjectId | Dueño (`users._id`, rol `user`) |
| `photo_id` | ObjectId \| ausente | Foto en el bucket `meal_photos`. Ausente en una captura manual sin foto |
| `eaten_at` | ISODate | Fecha y hora del registro; la pone el servidor |
| `date` | string | Día `YYYY-MM-DD` de `eaten_at` en la zona `APP_UTC_OFFSET` (México por defecto). Es el que filtra `GET /meals?date=` |
| `calories_kcal` | double | Valor final, 0 a 10 000 |
| `protein_g`, `fat_g` | double | Valores finales, 0 a 1 000 |

**Índices:** `user_id_date_eaten_at` → `{ user_id: 1, date: 1, eaten_at: 1 }` (registros de un usuario en un día, por hora;
también sirve para buscar por `user_id`) y `photo_id_unique` → `{ photo_id: 1 }`, único y parcial
(`partialFilterExpression: { photo_id: { $type: "objectId" } }`): una foto solo puede estar en un registro (el error `11000`
se traduce a `409 PHOTO_ALREADY_USED`), y los registros sin foto no chocan entre sí.

## Colección `coach_links` (`coach_link.rs`)

Vinculación entre un coach y un cliente (HU-05 y HU-13).

| Campo | Tipo | Notas |
|---|---|---|
| `_id` | ObjectId | Se expone como `id` (hex) |
| `coach_id` | ObjectId | Referencia a `users._id` (rol `coach`) |
| `user_id` | ObjectId | Referencia a `users._id` (rol `user`) |
| `status` | `"active"` \| `"unlinked"` | Solo `active` da acceso al cliente |
| `created_at` | ISODate | |

**Índices:** `coach_id_user_id_unique` → `{ coach_id: 1, user_id: 1 }`, único.

## Colección `coach_invite_codes` (`coach_invite_code.rs`)

Código de invitación de coach para vinculación de clientes (HU-12).

| Campo | Tipo | Notas |
|---|---|---|
| `_id` | ObjectId | Se expone como `id` (hex) |
| `coach_id` | ObjectId | Referencia a `users._id` (rol `coach`) |
| `code` | string | Código alfanumérico único de 6 caracteres en mayúsculas |
| `created_at` | ISODate | |
| `updated_at` | ISODate | Cambia al regenerar |

**Índices:** `coach_id_unique` → `{ coach_id: 1 }` (único) y `code_unique` → `{ code: 1 }` (único).

## Bucket de GridFS `meal_photos` (`meal_photo.rs`)

Fotos de comidas (TEC-13). GridFS las guarda en dos colecciones; el driver las escribe y el servicio `services/photos.rs`
es el único que las usa. El contenido no se guarda nunca en otra colección: los registros de comida (HU-09) guardan solo el id.

**`meal_photos.files`** — un documento por foto:

| Campo | Tipo | Notas |
|---|---|---|
| `_id` | ObjectId | Id de la foto que guardan los registros de comida |
| `filename` | string | El mismo id en hex (GridFS exige un nombre) |
| `length` | int | Tamaño en bytes (máx. 5 MiB) |
| `chunkSize` | int | 255 KiB (valor por defecto de GridFS) |
| `uploadDate` | ISODate | |
| `metadata.owner_id` | ObjectId | Dueño (`users._id`). Define quién puede leerla y eliminarla |
| `metadata.format` | `"jpeg"` | `"png"` | Detectado por contenido al guardar |

**`meal_photos.chunks`** — el contenido en trozos: `files_id` (→ `meal_photos.files._id`), `n` (orden) y `data` (binario).

**Índices:** `filename_1_uploadDate_1` en `files` y `files_id_1_n_1` (único) en `chunks`, los estándar de GridFS con su
nombre automático; y `metadata_owner_id` → `{ "metadata.owner_id": 1 }` en `files`, para las fotos de un usuario.

## Colección `exercises` (`exercise.rs`)

Catálogo base de ejercicios precargados (TEC-09) para las rutinas recomendadas del motor de reglas (TEC-10 / RF-14)
y la asignación de rutinas de coach (HU-18). Sebastián lo trabaja en paralelo con la vinculación.
Fecha límite: día 7 (20/10); es la tercera en salir si en la revisión del día 5 la ruta crítica va atrasada.
Cuenta con un mínimo acordado en el Sprint Planning de **18 ejercicios**, garantizando al menos uno por cada combinación
de los 6 grupos musculares y los 3 niveles de dificultad (`beginner`, `intermediate`, `advanced`).

| Campo | Tipo | Notas |
|---|---|---|
| `_id` | ObjectId | Se expone como `id` (hex) |
| `name` | string | Nombre único del ejercicio (identificador de negocio para upsert reproducible) |
| `muscle_group` | `"chest"` \| `"back"` \| `"legs"` \| `"shoulders"` \| `"arms"` \| `"core"` | Grupo muscular principal |
| `equipment` | string | Equipo requerido (p. ej. `"bodyweight"`, `"dumbbell"`, `"barbell"`, `"cable"`, `"machine"`, `"band"`) |
| `level` | `"beginner"` \| `"intermediate"` \| `"advanced"` | Nivel de dificultad (mismos valores que el perfil de usuario en HU-03) |
| `created_at` | ISODate | Momento de registro en el catálogo |

**Índices:**
- `exercise_name_unique` → `{ name: 1 }`, único (garantiza la reproducibilidad e idempotencia del script de carga, impidiendo duplicados).
- `exercise_muscle_group_level` → `{ muscle_group: 1, level: 1 }` (optimiza las consultas filtradas requeridas por el motor de reglas TEC-10 / RF-14 y la API).

