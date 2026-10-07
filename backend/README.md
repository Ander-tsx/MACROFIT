# Backend MacroFit (Rust + Axum + MongoDB)

API REST de MacroFit: autenticación, persistencia en MongoDB y reglas de acceso por rol (`user` y `coach`).
Historias cubiertas: **TEC-05** (base), **HU-01** (registro con rol) y **HU-02** (inicio y cierre de sesión).

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

Al arrancar se crean los índices (`users.email` único y los de `refresh_tokens`). Si la colección `users` ya tenía correos repetidos,
el arranque falla con un mensaje que lo indica: limpia esos documentos primero.

## ✅ Comprobaciones antes de subir

```bash
cd backend
cargo fmt --check
cargo clippy --all-targets -- -D warnings
cargo test
node postman/build.js --check
```

Y la colección de Postman sin fallos (ver [postman/README.md](postman/README.md)).

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
| POST | `/auth/register` | — | HU-01 | Crea una cuenta con rol |
| POST | `/auth/login` | — | HU-02 | Abre una sesión: access + refresh token |
| POST | `/auth/refresh` | — | HU-02 | Rota el refresh token y entrega tokens nuevos |
| POST | `/auth/logout` | Bearer | HU-02 | Cierra (revoca) la sesión |
| GET | `/auth/me` | Bearer | HU-02 | Datos y rol de la cuenta del token |
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
| `privacy_accepted` | **Pendiente de TEC-07**: hoy no se exige. Si es `true` se guarda `privacy_accepted_at` |

La confirmación de contraseña la valida la app; el backend no la recibe.

**201 Created**

```json
{ "id": "6ac67c70...", "name": "Ana", "email": "ana@macrofit.com", "role": "user", "profile_completed": false }
```

**Errores:** `400 VALIDATION_ERROR` (campo en `fields`), `400 INVALID_BODY`, `409 EMAIL_ALREADY_EXISTS`
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

### GET `/coach/test`

Misma autenticación que `/auth/me`. **200 OK** `{ "user_id", "role" }` para coaches; `403 FORBIDDEN` para `user`.

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
| `PRIVACY_NOT_ACCEPTED` | 400 | *(Reservado para TEC-07)* No se aceptó el aviso de privacidad |
| `INVALID_CREDENTIALS` | 401 | Login con correo o contraseña incorrectos |
| `UNAUTHORIZED` | 401 | Falta el access token, está alterado o expiró |
| `INVALID_REFRESH_TOKEN` | 401 | Refresh token desconocido, expirado o de otra sesión |
| `TOKEN_REVOKED` | 401 | La sesión fue cerrada o revocada (logout, token rotado o reuso) |
| `FORBIDDEN` | 403 | El rol no tiene acceso |
| `EMAIL_ALREADY_EXISTS` | 409 | El correo ya está registrado |
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
