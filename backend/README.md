# Backend MacroFit (Rust + Axum + MongoDB)

API REST de MacroFit: autenticación, persistencia en MongoDB y reglas de acceso por rol (`user` y `coach`).
Historias cubiertas: **TEC-05** (base), **TEC-07** (aviso de privacidad), **HU-01** (registro con rol), **HU-02** (inicio y cierre de sesión)
y **HU-03** (perfil inicial del usuario).

> **Si eres una persona o una sesión de IA que va a modificar este backend, lee primero
> la sección [Forma de trabajo](#-forma-de-trabajo) y el README de la carpeta que vas a tocar.**
> Cada carpeta de `src/` y `postman/` tiene un `README.md` con sus reglas.
> Los agentes de IA siguen además [AGENTS.md](AGENTS.md) (todos) y [CLAUDE.md](CLAUDE.md) (Claude Code).

---

## 🛠️ Tecnologías

| Pieza | Uso |
|---|---|
| Rust (edición 2024) + [Axum 0.7](https://github.com/tokio-rs/axum) sobre Tokio | Servidor HTTP |
| [MongoDB](https://www.mongodb.com/) (driver oficial 3.x) | Base de datos (Atlas o local) |
| `argon2` (Argon2id) | Hash de contraseñas |
| `jsonwebtoken` | Access tokens JWT de corta duración |
| `sha2` + `rand` | Refresh tokens opacos (solo se guarda su SHA-256) |
| `dotenvy` | Variables de entorno desde `.env` |

## 📋 Requisitos

1. Rust y Cargo ([rustup.rs](https://rustup.rs/)).
2. MongoDB: cluster de Atlas (usuario con lectura/escritura e IP permitida en *Network Access*) o MongoDB local.
3. Postman o `newman` para las pruebas de API.

## ⚙️ Configuración (`.env`)

Copia `.env.example` a `.env` dentro de `backend/`. **`.env` nunca se sube al repositorio.**

| Variable | Obligatoria | Descripción |
|---|---|---|
| `MONGO_URI` | Sí | Cadena de conexión (Atlas o `mongodb://localhost:27017`) |
| `DB_NAME` | Sí | Nombre de la base de datos |
| `JWT_SECRET` | Sí | Clave para firmar los JWT. El servidor no arranca sin ella |
| `PORT` | No (3000) | Puerto HTTP |
| `APP_ENV` | No | `development` monta las rutas de datos de prueba (`/dev`); omítela en producción |
| `ACCESS_TOKEN_MINUTES` | No (15) | Vida del access token (JWT) |
| `REFRESH_TOKEN_DAYS` | No (30) | Vida del refresh token; se renueva en cada rotación |

> Si la contraseña de Atlas tiene `@`, `:` o `/`, codifícalos en formato URL.

## 🚀 Ejecutar

```bash
cd backend
cargo run
```

Salida esperada:

```text
Conectando y verificando cluster de MongoDB...
¡Ping exitoso! Conexión establecida correctamente con MongoDB.
Servidor MacroFit corriendo en http://0.0.0.0:3000/api/v1
```

Al arrancar se crean los índices (`users.email` único, los de `refresh_tokens` y `profiles.user_id` único). Si la colección `users` ya tenía correos repetidos,
el arranque falla con un mensaje que lo indica: limpia esos documentos primero.

## ✅ Comprobaciones antes de subir

```bash
cd backend
cargo fmt --check
cargo clippy --all-targets -- -D warnings
cargo test
node postman/build.js --check
```

Y la colección de Postman sin fallos (ver [postman/README.md](postman/README.md)). Los scripts de [../scripts](../scripts/README.md) hacen todo esto con un comando: `scripts/check.sh backend` y `scripts/api-test.sh`.

---

## 🧭 Forma de trabajo

### Estructura

```
backend/
├── Cargo.toml
├── .env.example          # Plantilla de configuración (sin secretos)
├── postman/              # Una colección por módulo + combinado generado → postman/README.md
└── src/
    ├── main.rs           # Arranque: config → db → router. Sin lógica de negocio
    ├── config.rs         # Lectura de variables de entorno
    ├── state.rs          # AppState compartido (db, configuración de tokens)
    ├── db.rs             # Conexión a MongoDB y creación de índices
    ├── error.rs          # AppError + formato de error único + extractor ApiJson
    ├── validation.rs     # Reglas de validación reutilizables (funciones puras)
    ├── routes/           # Capa HTTP: rutas, DTOs, handlers → src/routes/README.md
    ├── services/         # Lógica de negocio por dominio → src/services/README.md
    ├── models/           # Documentos de MongoDB → src/models/README.md
    └── auth/             # JWT, refresh tokens, hash de contraseñas, extractores de sesión/rol → src/auth/README.md
```

Más detalle en [src/README.md](src/README.md).

### Flujo de una petición

```
HTTP → routes (DTO + handler) → services (validación + reglas + Mongo) → models
                ↑                         │
          auth (extractores)        AppError → { "error": { code, message, fields } }
```

### Reglas que mantienen la consistencia

1. **Rutas versionadas**: todo cuelga de `/api/v1` (`routes::API_PREFIX`).
2. **Un único formato de error**: todo handler devuelve `Result<_, AppError>`. Nunca construyas JSON de error a mano.
3. **Leer cuerpos con `ApiJson<T>`**, no con `axum::Json`, para que un JSON inválido responda con el formato de la API.
4. **Campos de entrada como `Option<T>`** en los DTOs; la validación decide qué falta y lo reporta por campo.
5. **Validar todos los campos a la vez** y devolver `AppError::Validation(fields)` con todos los inválidos.
6. **Correos normalizados** (`validation::normalize_email`) antes de guardar o buscar.
7. **Nunca exponer `password_hash`**: las respuestas usan DTOs (`UserResponse`), nunca el modelo de Mongo.
8. **Operaciones costosas de CPU** (hash Argon2) dentro de `tokio::task::spawn_blocking`.
9. **Roles en minúsculas**: `"user"` y `"coach"` (enum `Role`, serializado en minúsculas).
10. **Pruebas**: lógica pura con `#[cfg(test)]` en el mismo archivo; contrato HTTP en Postman (`postman/<modulo>/`, una carpeta por HU).
11. **Textos al cliente en español**; identificadores de código en inglés; comentarios en español.
12. **Decisiones pendientes** se marcan con `// TODO(ID-BACKLOG): ...` (p. ej. `TODO(TEC-07)`).

### Cómo agregar un endpoint nuevo

1. Si hay colección nueva: modelo en `src/models/` + índices en `db.rs::ensure_indexes`.
2. Lógica en `src/services/<dominio>.rs` (validación + acceso a Mongo), con pruebas unitarias.
3. DTOs y handler en `src/routes/<dominio>.rs`; registra la ruta en su `router()` y, si el módulo es nuevo, haz `merge` en `routes::api_router`.
4. Si aparece un código de error nuevo: variante en `AppError` + fila en la [tabla de códigos](#códigos-de-error).
5. Carpeta `HU-XX <nombre>` en `postman/<modulo>/<modulo>.postman_collection.json` (mismo nombre que `src/routes/<modulo>.rs`) con tests de estado y estructura, y `node postman/build.js` para regenerar el combinado.
6. Actualiza el [catálogo de endpoints](#-catálogo-de-endpoints) de este README.

---

## 📖 Catálogo de endpoints

URL base: `http://localhost:3000/api/v1`

| Método | Ruta | Auth | Historia | Descripción |
|---|---|---|---|---|
| GET | `/health` | — | TEC-05 | Responde `API MacroFit OK` |
| GET | `/legal/privacy` | — | TEC-07 | Versión vigente y texto completo (Markdown) del aviso de privacidad |
| POST | `/auth/register` | — | HU-01 | Crea una cuenta con rol |
| POST | `/auth/login` | — | HU-02 | Abre una sesión: access + refresh token |
| POST | `/auth/refresh` | — | HU-02 | Rota el refresh token y entrega tokens nuevos |
| POST | `/auth/logout` | Bearer | HU-02 | Cierra (revoca) la sesión |
| GET | `/auth/me` | Bearer | HU-02 | Datos y rol de la cuenta del token |
| POST | `/users/me/profile` | Bearer (user) | HU-03 | Crea el perfil inicial y marca `profile_completed` |
| GET | `/users/me/profile` | Bearer (user) | HU-03 | Perfil del usuario de la sesión |
| PATCH | `/users/me/profile` | Bearer (user) | HU-03 | Edita solo los campos enviados del perfil |
| GET | `/users/me/goals/current` | Bearer (user) | HU-04 | Meta nutricional vigente |
| GET | `/users/me/goals` | Bearer (user) | HU-04 | Historial de metas (más reciente primero) |
| GET | `/coach/clients` | Bearer (coach) | HU-05 | Clientes con vinculación activa |
| GET | `/coach/clients/{clientId}/goals` | Bearer (coach) | HU-05 | Historial de metas de un cliente vinculado |
| POST | `/coach/clients/{clientId}/goals` | Bearer (coach) | HU-05 | Fija una meta para un cliente vinculado |
| POST | `/dev/seed/coach-links` | — (solo `APP_ENV=development`) | HU-05 | Vincula un coach con un usuario de prueba |
| GET | `/coach/test` | Bearer (coach) | TEC-05 | Prueba de la regla de acceso por rol |

### POST `/auth/register` (HU-01)

```json
{
  "name": "Ana",
  "email": "ana@macrofit.com",
  "password": "MinimoOcho",
  "role": "user",
  "privacy_accepted": true
}
```

| Campo | Regla |
|---|---|
| `name` | Obligatorio, no vacío tras quitar espacios, máx. 100 caracteres |
| `email` | Obligatorio, formato válido, máx. 254. Se guarda en minúsculas y sin espacios |
| `password` | 8 a 128 caracteres. Se guarda solo como hash Argon2id |
| `role` | `"user"` o `"coach"` (exacto, en minúsculas) |
| `privacy_accepted` | Debe ser `true`. Se guardan `privacy_accepted_at` y `privacy_version` (versión vigente del aviso) |

La confirmación de contraseña la valida la app; el backend no la recibe.

**201 Created**

```json
{ "id": "6ac67c70...", "name": "Ana", "email": "ana@macrofit.com", "role": "user", "profile_completed": false }
```

**Errores:** `400 VALIDATION_ERROR` (campo en `fields`), `400 PRIVACY_NOT_ACCEPTED`, `400 INVALID_BODY`, `409 EMAIL_ALREADY_EXISTS`
(también si el correo solo difiere en mayúsculas).

### Modelo de sesión (HU-02)

- **Access token**: JWT HS256 con `sub` (id), `role`, `sid` (id de sesión), `iat` y `exp` (15 min). Se envía como
  `Authorization: Bearer <token>`.
- **Refresh token**: valor opaco aleatorio (64 caracteres hex). En `refresh_tokens` solo se guarda su SHA-256.
- **Sesión**: nace en el login (`session_id`) y sigue activa mientras tenga un refresh token sin revocar ni expirar.
  El middleware lo comprueba en cada petición protegida, así que **cerrar sesión invalida al instante el access token**.
- **Rotación**: cada `/auth/refresh` revoca el refresh token usado y entrega uno nuevo en la misma sesión, con vigencia
  renovada a 30 días (la sesión se mantiene mientras la app se use al menos una vez al mes).
- **Detección de reuso**: presentar un refresh token ya revocado responde `401 TOKEN_REVOKED` y **revoca la sesión
  completa**: si alguien usa un token robado, ambas partes pierden la sesión y la persona legítima vuelve a iniciarla.
- La app guarda ambos tokens en almacenamiento seguro y, ante un `401 UNAUTHORIZED` por access token expirado, llama
  a `/auth/refresh` una sola vez antes de mandar a la persona al login. Con `TOKEN_REVOKED` va directo al login.

### Aviso de privacidad (TEC-07)

- `GET /legal/privacy` responde `200` con `{ "version": "1.0", "content": "# Aviso de privacidad..." }`.
- El texto se **embebe al compilar** desde `../docs/legal/aviso-de-privacidad.md` (`include_str!`): es la única fuente de
  verdad. Para cambiar el aviso se edita ese archivo, se sube la línea `**Versión:**` y se recompila el backend.
- La versión se lee de la línea `**Versión:** x.y` del documento; si falta, el servidor no arranca.
- En el registro, si `privacy_accepted` no es `true`:
  - con el resto de campos válidos → `400 PRIVACY_NOT_ACCEPTED` (`fields.privacy_accepted`);
  - con otros campos inválidos → `400 VALIDATION_ERROR` con `privacy_accepted` como un campo más.

### POST `/auth/login`

Cuerpo `{ "email", "password" }`. **200 OK**:

```json
{
  "access_token": "eyJ...",
  "refresh_token": "9f2c...",
  "token_type": "Bearer",
  "expires_in": 900,
  "user": { "id": "...", "name": "Ana", "email": "ana@macrofit.com", "role": "coach", "profile_completed": false }
}
```

Errores: `400 VALIDATION_ERROR`, `401 INVALID_CREDENTIALS` (mismo código y mensaje si el correo no existe o la
contraseña es incorrecta; además se iguala el tiempo de respuesta).

### POST `/auth/refresh`

Cuerpo `{ "refresh_token" }`. **200 OK**: misma forma que el login, con tokens nuevos.
Errores: `400 VALIDATION_ERROR`, `401 INVALID_REFRESH_TOKEN` (desconocido o expirado), `401 TOKEN_REVOKED`
(ya rotado o sesión cerrada; revoca la sesión).

### POST `/auth/logout`

Cabecera `Authorization: Bearer <access_token>` y cuerpo `{ "refresh_token" }` de la misma sesión.
**204 No Content**. Revoca todos los refresh tokens de la sesión y el access token deja de funcionar.
Errores: `400 VALIDATION_ERROR`, `401 UNAUTHORIZED`, `401 TOKEN_REVOKED` (sesión ya cerrada),
`401 INVALID_REFRESH_TOKEN` (el refresh token no es de esta sesión).

### GET `/auth/me`

Cabecera `Authorization: Bearer <access_token>`. **200 OK**: `{ id, name, email, role, profile_completed }`.
Errores: `401 UNAUTHORIZED` (sin token, alterado o expirado), `401 TOKEN_REVOKED` (sesión cerrada).

### Perfil inicial — `/users/me/profile` (HU-03)

Cabecera `Authorization: Bearer <access_token>`. **Solo rol `user`**: un coach recibe `403 FORBIDDEN_ROLE` en los tres métodos.

**POST** (todos los campos obligatorios):

```json
{
  "objective": "lose_fat",
  "level": "beginner",
  "training_days": 4,
  "weight_kg": 72.5,
  "height_cm": 170,
  "gender": "female",
  "birth_date": "1996-05-20"
}
```

| Campo | Regla |
|---|---|
| `objective` | `"lose_fat"`, `"maintain"` o `"gain_muscle"` (exacto, en minúsculas) |
| `level` | `"beginner"`, `"intermediate"` o `"advanced"` |
| `training_days` | Entero de 1 a 7 (un número con decimales se señala en el campo) |
| `weight_kg` | Número de 30 a 300 (kg) |
| `height_cm` | Número de 100 a 250 (cm) |
| `gender` | `"male"` o `"female"` |
| `birth_date` | Fecha válida `YYYY-MM-DD`; edad de 18 a 100 años cumplidos a la fecha UTC actual; no futura |

> Rangos provisionales hasta **TEC-12** (`services::profile::WEIGHT_MIN_KG`, etc.). Si cambian, cambia también
> `macrofit_app/lib/features/profile/domain/validators/profile_validators.dart`.

**201 Created** — además marca `users.profile_completed = true` (visible en `GET /auth/me`):

```json
{
  "id": "6ac6...", "user_id": "6ac5...",
  "objective": "lose_fat", "level": "beginner", "training_days": 4,
  "weight_kg": 72.5, "height_cm": 170.0, "gender": "female", "birth_date": "1996-05-20",
  "created_at": "2026-10-08T21:40:00Z", "updated_at": "2026-10-08T21:40:00Z"
}
```

Errores: `400 VALIDATION_ERROR` (cada campo inválido en `fields`), `400 INVALID_BODY`, `409 PROFILE_ALREADY_EXISTS`.

**GET** → `200` con la misma forma. Error: `404 PROFILE_NOT_FOUND` si aún no lo captura.

**PATCH** → cuerpo con uno o más campos del POST (los ausentes o `null` no cambian; mismas reglas). `200` con el perfil
actualizado y `updated_at` nuevo. Errores: `400 VALIDATION_ERROR`, `400 INVALID_BODY` (sin ningún campo),
`404 PROFILE_NOT_FOUND`.

**Meta nutricional (HU-04):** al crear el perfil se genera la meta inicial; al editarlo se recalcula solo si cambian
`weight_kg`, `objective` o `training_days`, y nunca si la meta vigente la fijó un coach.

### Metas por coach — `/coach/clients/{clientId}/goals` (HU-05)

Cabecera `Authorization: Bearer <access_token>`. **Solo rol `coach`** (`403 FORBIDDEN_ROLE` para un `user`) y solo con una
vinculación activa con el cliente (`403 CLIENT_NOT_LINKED`, también si el id no existe o está mal formado).
La vinculación se comprueba antes de validar el cuerpo.

**POST** (todos los campos obligatorios):

```json
{ "calories": 2200, "protein_g": 160, "fat_g": 70, "effective_from": "2026-10-09" }
```

| Campo | Regla |
|---|---|
| `calories` | Entero de 1 a 10 000 |
| `protein_g`, `fat_g` | Entero de 1 a 1 000 |
| `effective_from` | Fecha válida `YYYY-MM-DD` (medianoche UTC) |

**201 Created** — misma forma que `GET /users/me/goals/current` (HU-04) con `source: "coach"` y `set_by` igual al id del coach.
La meta se agrega al historial; las anteriores no se modifican. Errores: `400 VALIDATION_ERROR` (campos en `fields`;
un texto o un decimal se señalan en su campo), `400 INVALID_BODY`.

**GET** → `200` con el historial completo del cliente (metas del coach y calculadas), la más reciente primero.

**Meta vigente (HU-04 y HU-05):** es la de `effective_from` más reciente que ya empezó (las de fecha futura todavía no
aplican). Una meta de coach vigente tiene prioridad sobre las calculadas, y editar el perfil nunca la reemplaza.
Un cliente sin perfil recibe la meta del coach en `GET /users/me/goals/current`.

**GET `/coach/clients`** → `200` con `[{ "id", "name", "email" }]` de los clientes vinculados, por nombre.

### POST `/dev/seed/coach-links` (HU-05)

Solo existe con `APP_ENV=development`; en cualquier otro ambiente la ruta no se monta (`404`). Sin autenticación.
Cuerpo `{ "coach_id", "user_id" }` (ids de cuentas existentes con rol `coach` y `user`). **201** con la vinculación
`active` (la crea o la reactiva). Errores: `400 VALIDATION_ERROR`.

### GET `/coach/test`

Misma autenticación que `/auth/me`. **200 OK** `{ "user_id", "role" }` para coaches; `403 FORBIDDEN_ROLE` para `user`.

---

## ❗ Formato de error

Todas las respuestas de error tienen la misma forma. `fields` siempre es un objeto (vacío si no aplica):

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Hay campos inválidos",
    "fields": {
      "email": "El correo no tiene un formato válido",
      "password": "La contraseña debe tener al menos 8 caracteres"
    }
  }
}
```

### Códigos de error

| Código | HTTP | Cuándo |
|---|---|---|
| `VALIDATION_ERROR` | 400 | Uno o más campos inválidos; detalle en `fields` |
| `INVALID_BODY` | 400 | JSON malformado o tipo de dato incorrecto |
| `PRIVACY_NOT_ACCEPTED` | 400 | No se aceptó el aviso de privacidad y el resto de campos es válido |
| `INVALID_CREDENTIALS` | 401 | Login con correo o contraseña incorrectos |
| `UNAUTHORIZED` | 401 | Falta el access token, está alterado o expiró |
| `INVALID_REFRESH_TOKEN` | 401 | Refresh token desconocido, expirado o de otra sesión |
| `TOKEN_REVOKED` | 401 | La sesión fue cerrada o revocada (logout, token rotado o reuso) |
| `FORBIDDEN_ROLE` | 403 | La función es exclusiva de otro rol (p. ej. el perfil, solo para `user`; las metas por coach, solo para `coach`) |
| `CLIENT_NOT_LINKED` | 403 | El coach no tiene una vinculación activa con el cliente |
| `PROFILE_NOT_FOUND` | 404 | El usuario aún no tiene perfil |
| `EMAIL_ALREADY_EXISTS` | 409 | El correo ya está registrado |
| `PROFILE_ALREADY_EXISTS` | 409 | El usuario ya tiene un perfil (se edita con `PATCH`) |
| `INTERNAL_ERROR` | 500 | Error inesperado (el detalle solo va al log del servidor) |

---

## 🗄️ Base de datos

Ver [src/models/README.md](src/models/README.md) para el esquema de cada colección.

Evidencia de que la contraseña se guarda solo como hash (`mongosh`):

```js
db.users.find({}, { name: 1, email: 1, password_hash: 1, role: 1 }).sort({ created_at: -1 }).limit(3)
db.users.countDocuments({ password: { $exists: true } })   // debe ser 0

// Sesiones: solo se guarda el hash del refresh token
db.refresh_tokens.find({}, { _id: 0 }).sort({ created_at: -1 }).limit(3)
```
