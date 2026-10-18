# Backend MacroFit (Rust + Axum + MongoDB)

API REST de MacroFit: autenticación, persistencia en MongoDB y reglas de acceso por rol (`user` y `coach`).
Historias cubiertas: **TEC-05** (base), **TEC-07** (aviso de privacidad), **HU-01** (registro con rol), **HU-02** (inicio y cierre de sesión)
**HU-03** (perfil inicial del usuario), **HU-04** y **HU-05** (metas), **TEC-13** (almacenamiento de fotos de comidas),
**TEC-14** (contrato de la API en OpenAPI), **HU-06** (carga de la foto de comida), **TEC-02** (comparación de servicios de reconocimiento de alimentos), **HU-07** (estimación nutricional de la foto) y **HU-09** (registros de comida).

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
| GridFS (driver de MongoDB) + `futures-util` | Almacenamiento de fotos de comidas (TEC-13) |
| [`utoipa`](https://github.com/juhaku/utoipa) + `utoipa-swagger-ui` | Especificación OpenAPI generada desde el código y Swagger UI (TEC-14) |
| `reqwest` + `async-trait` + `base64` + `image` | Adaptadores de reconocimiento de alimentos y preparación de la foto (TEC-02) |

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
| `APP_UTC_OFFSET` | No (`-06:00`) | Zona horaria fija (`±HH:MM`) con la que se define el día de un registro de comida (HU-09). Por defecto, hora del centro de México |
| `FOOD_PROVIDER` | No (`simulator`) | Proveedor de reconocimiento de alimentos: `simulator`, `logmeal`, `gemini` o `gemini_fatsecret` (TEC-02) |
| `FOOD_PROVIDER_TIMEOUT_SECS` | No (10) | Tiempo de espera con el proveedor, de 1 a 10 s (RNF-01) |
| `FOOD_SIMULATOR_MODE` | No (`ok`) | Respuesta del simulador: `ok`, `not_recognized`, `error` o `timeout` |
| `LOGMEAL_API_TOKEN` | Con `logmeal` | Token de un **APIUser** de LogMeal |
| `GEMINI_API_KEY`, `GEMINI_MODEL` | Con `gemini*` | Llave de Google AI Studio y modelo (por defecto `gemini-2.5-flash`) |
| `FATSECRET_CLIENT_ID`, `FATSECRET_CLIENT_SECRET` | Con `gemini_fatsecret` | Credenciales OAuth 2.0 de FatSecret Platform |

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

Al arrancar se crean los índices (`users.email` único, los de `refresh_tokens`, `profiles.user_id` único, `goals`, `coach_links`, `exercises.name` único y compuesto por grupo/nivel, los del bucket de fotos `meal_photos` y los de `meals`). Si la colección `users` ya tenía correos repetidos,
el arranque falla con un mensaje que lo indica: limpia esos documentos primero.

## ✅ Comprobaciones antes de subir

```bash
cd backend
cargo fmt --check
cargo clippy --all-targets -- -D warnings
cargo test
node postman/build.js --check
```

La CI del backend ([backend-ci.yml](../.github/workflows/backend-ci.yml)) corre `cargo fmt --check`, `cargo clippy` y `cargo test` en cada pull request; con la CI en rojo no se fusiona. No usa secretos ni MongoDB.

Y la colección de Postman sin fallos (ver [postman/README.md](postman/README.md)). Los scripts de [../scripts](../scripts/README.md) hacen todo esto con un comando: `scripts/check.sh backend` y `scripts/api-test.sh`.

---

## 🧭 Forma de trabajo

### Estructura

```
backend/
├── Cargo.toml
├── .env.example          # Plantilla de configuración (sin secretos)
├── postman/              # Una colección por módulo + combinado generado → postman/README.md
├── bench/                # TEC-02: banco de pruebas de reconocimiento de alimentos → bench/README.md
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
4. **Contrato OpenAPI**: `#[utoipa::path(...)]` en el handler, `ToSchema` en sus DTOs y el handler en `paths(...)` de `src/routes/openapi.rs`. Pasos en [src/routes/README.md](src/routes/README.md#documentar-un-endpoint-en-openapi-tec-14).
5. Si aparece un código de error nuevo: variante en `AppError` + fila en la [tabla de códigos](#códigos-de-error).
6. Carpeta `HU-XX <nombre>` en `postman/<modulo>/<modulo>.postman_collection.json` (mismo nombre que `src/routes/<modulo>.rs`) con tests de estado y estructura, y `node postman/build.js` para regenerar el combinado.
7. Actualiza el [catálogo de endpoints](#-catálogo-de-endpoints) de este README.

---

## 📖 Catálogo de endpoints

URL base: `http://localhost:3000/api/v1`

El contrato completo (cuerpos, respuestas y códigos de error de cada endpoint) está en **Swagger UI**:
`http://localhost:3000/api/v1/docs` (ver [Contrato OpenAPI](#contrato-openapi-tec-14)).

| Método | Ruta | Auth | Historia | Descripción |
|---|---|---|---|---|
| GET | `/health` | — | TEC-05 | Responde `API MacroFit OK` |
| GET | `/openapi.json` | — | TEC-14 | Especificación OpenAPI 3.1 generada desde el código |
| GET | `/docs` | — | TEC-14 | Swagger UI: documentación navegable del contrato |
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
| POST | `/users/me/weights` | Bearer (user) | HU-21 | Registra un peso y lo pasa al perfil |
| GET | `/users/me/weights` | Bearer (user) | HU-21 | Historial de peso (más reciente primero) |
| GET | `/coach/clients` | Bearer (coach) | HU-05, HU-24 | Clientes con vinculación activa, con su meta vigente y su último registro de comida |
| GET | `/coach/clients/{clientId}/goals` | Bearer (coach) | HU-05 | Historial de metas de un cliente vinculado |
| POST | `/coach/clients/{clientId}/goals` | Bearer (coach) | HU-05 | Fija una meta para un cliente vinculado |
| GET | `/coach/invite-code` | Bearer (coach) | HU-12 | Código de invitación del coach (lo crea si no existe) |
| POST | `/coach/invite-code/regenerate` | Bearer (coach) | HU-12 | Reemplaza el código de invitación por uno nuevo |
| POST | `/meals/photos` | Bearer (user) | HU-06 | Sube la foto de una comida (multipart, campo `photo`) |
| POST | `/meals/estimate` | Bearer (user) | HU-07 | Estima calorías, proteína y grasa de una foto propia |
| POST | `/meals` | Bearer (user) | HU-09 | Guarda un registro de comida (foto opcional y valores finales) |
| GET | `/meals?date=YYYY-MM-DD` | Bearer (user) | HU-09 | Registros del usuario en ese día, por hora |
| DELETE | `/meals/{id}` | Bearer (user) | HU-09 | Elimina un registro propio y su foto |
| POST | `/dev/seed/coach-links` | — (solo `APP_ENV=development`) | HU-05 | Vincula un coach con un usuario de prueba |
| GET | `/coach/test` | Bearer (coach) | TEC-05 | Prueba de la regla de acceso por rol |
| GET | `/coach/invite-code` | Bearer (coach) | HU-12 | Código de invitación del coach; se crea si no existe |
| POST | `/coach/invite-code/regenerate` | Bearer (coach) | HU-12 | Genera un código nuevo; el anterior deja de ser válido |
| POST | `/users/me/coach-link` | Bearer (user) | HU-13 | Vincula al usuario con un coach mediante su código de invitación |
| DELETE | `/users/me/coach-link` | Bearer (user) | HU-14 | Desvincula al usuario de su coach activo |

### Contrato OpenAPI (TEC-14)

- `GET /api/v1/openapi.json`: especificación **OpenAPI 3.1** generada al compilar desde los handlers y DTOs
  (`utoipa`); nunca se edita a mano. `GET /api/v1/docs`: Swagger UI con *Try it out*.
- Se monta en **todos los ambientes** (la Sprint Review se hace con esta documentación sobre el ambiente
  desplegado). Las rutas `/dev` solo aparecen con `APP_ENV=development`, igual que se montan.
- Rutas protegidas: esquema `bearer_auth` (JWT). Su lista indica el rol: vacía = cualquier sesión,
  `["user"]` o `["coach"]`. En Swagger UI, **Authorize** con el `access_token` de `/auth/login`.
- Errores: todas las respuestas de error referencian el esquema único `ErrorResponse`, el mismo struct que
  serializa `AppError`; la descripción de cada respuesta nombra sus códigos.
- Cada elemento -API documenta sus endpoints al terminarse: ver
  [src/routes/README.md](src/routes/README.md#documentar-un-endpoint-en-openapi-tec-14).

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
| `weight_kg` | Número de 35 a 250 (kg) |
| `height_cm` | Número de 130 a 230 (cm) |
| `gender` | `"male"` o `"female"` |
| `birth_date` | Fecha válida `YYYY-MM-DD`; edad de 18 a 80 años cumplidos a la fecha UTC actual; no futura |

> Rangos definidos en **TEC-12** (`services::profile::WEIGHT_MIN_KG`, etc.; justificación en
> [`src/services/README.md`](src/services/README.md#meta-nutricional-hu-04-y-tec-12)). El registro de peso (HU-21)
> valida con `services::profile::parse_weight_kg`.
>
> **Pendiente en la app (Sprint 3):** `macrofit_app/lib/features/profile/domain/validators/profile_validators.dart`
> todavía usa los rangos provisionales (30–300 kg, 100–250 cm, 18–100 años) y el cálculo local de la meta en
> `macrofit_app/lib/features/goals/` no aplica el mínimo de calorías. Hasta entonces el backend rechaza con
> `VALIDATION_ERROR` lo que la app deje pasar fuera de los rangos nuevos.

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
`weight_kg`, `objective` o `training_days`, y nunca si la meta vigente la fijó un coach. La fórmula (TEC-12) está en
[`src/services/README.md`](src/services/README.md#meta-nutricional-hu-04-y-tec-12).

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

### Lista de clientes — GET `/coach/clients` (HU-05, HU-24)

Cabecera `Authorization: Bearer <access_token>`. **Solo rol `coach`** (`403 FORBIDDEN_ROLE` para un `user`; sin sesión
`401 UNAUTHORIZED`). Devuelve solo los clientes con vinculación **activa** (un cliente desvinculado en HU-14 no aparece),
ordenados por nombre:

```json
[
  {
    "id": "6ad0a1b2c3d4e5f6a7b8c9d0",
    "name": "Ana",
    "email": "ana@macrofit.com",
    "goal": { "calories": 2200, "protein_g": 160, "fat_g": 70, "source": "coach" },
    "last_meal_at": "2026-10-17T01:30:00Z"
  }
]
```

| Campo | Contenido |
|---|---|
| `id`, `name`, `email` | Los de HU-05; se conservan para no romper la app |
| `goal` | Meta vigente con la misma regla que `GET /users/me/goals/current` (la del coach tiene prioridad; las de fecha futura no cuentan). `source`: `system` o `coach`. `null` si el cliente aún no tiene metas (sin perfil ni meta del coach) |
| `last_meal_at` | Fecha y hora (RFC 3339, UTC) del registro de comida más reciente (HU-09). `null` si no tiene registros |

La meta y el último registro se obtienen **en lote** (una consulta de metas con `$in` y una agregación `$group`/`$max`
sobre `meals`), no con una consulta por cliente.

### Código de invitación — `/coach/invite-code` (HU-12)

Cabecera `Authorization: Bearer <access_token>`. **Solo rol `coach`** (`403 FORBIDDEN_ROLE` para un `user`).
Cada coach tiene un único código de 6 caracteres (`A-Z0-9`).

**GET** → `200` con `{ "code": "K7P2QX" }`. Si el coach aún no tiene código, se genera y se guarda.

**POST `/coach/invite-code/regenerate`** → `200` con `{ "code": "..." }`, siempre distinto al anterior.
El código anterior deja de ser válido.

### POST `/users/me/coach-link` (HU-13)

Cabecera `Authorization: Bearer <access_token>`. **Solo rol `user`** (`403 FORBIDDEN_ROLE` para un `coach`).

```json
{ "invite_code": "K7P2QX" }
```

| Campo | Regla |
|---|---|
| `invite_code` | Obligatorio. Se normaliza (sin espacios alrededor y en mayúsculas) |

Un usuario solo puede tener **una vinculación activa**. Si ya existía una vinculación previa con ese coach, se reactiva.

**201 Created**

```json
{ "id": "6ac6...", "coach_id": "6ac5...", "coach_name": "Laura", "coach_email": "laura@macrofit.com", "status": "active" }
```

**Errores:** `400 VALIDATION_ERROR` (falta `invite_code`), `400 INVALID_BODY`, `401 UNAUTHORIZED`,
`403 FORBIDDEN_ROLE`, `404 INVITE_CODE_NOT_FOUND` (el código no existe o su dueño ya no es coach),
`409 USER_ALREADY_LINKED`.

### DELETE `/users/me/coach-link` (HU-14)

Cabecera `Authorization: Bearer <access_token>`. **Solo rol `user`** (`403 FORBIDDEN_ROLE` para un `coach`).

Desvincula al usuario autenticado de su coach activo actualizando el estado de la vinculación a `"unlinked"`.

**204 No Content**

**Errores:** `401 UNAUTHORIZED`, `403 FORBIDDEN_ROLE`, `404 USER_NOT_LINKED` (el usuario no tiene ninguna vinculación activa).

### Registro de peso — `/users/me/weights` (HU-21)

Solo rol `user` (`UserOnly`); sin sesión `401 UNAUTHORIZED`, una cuenta de coach `403 FORBIDDEN_ROLE`.

**POST** — cuerpo `{ "weight_kg": 78.2 }`. La fecha la pone el servidor (no se envía). `weight_kg` debe ser un número
de 35 a 250 kg, el mismo rango del perfil (TEC-12, `services::profile::parse_weight_kg`).

```json
{ "id": "6ac7...", "user_id": "6ac5...", "weight_kg": 78.2, "recorded_at": "2026-10-13T16:05:00Z" }
```

`201 Created`. Si el usuario ya tiene perfil, el peso pasa a ser su `weight_kg` y la meta calculada se recalcula como
en una edición del perfil (HU-04; una meta de coach no se toca). Sin perfil, el peso se guarda igual.
Errores: `400 VALIDATION_ERROR` en `weight_kg` (ausente, `null`, no numérico o fuera de rango), `400 INVALID_BODY`.

**GET** → `200` con `[{ "id", "user_id", "weight_kg", "recorded_at" }]` del usuario de la sesión, del más reciente al
más antiguo (`[]` si no hay registros).

### POST `/meals/photos` (HU-06)

Cabecera `Authorization: Bearer <access_token>`. **Solo rol `user`** (`403 FORBIDDEN_ROLE` para un coach).
Cuerpo `multipart/form-data` con el archivo en el campo **`photo`**; los demás campos se ignoran y, si hay varios
`photo`, se toma el primero. Reglas de TEC-13: solo **JPEG o PNG** (se revisa el contenido, no la extensión ni el
`Content-Type`) y como máximo **5 MiB**; el tamaño se revisa antes que el tipo.

```bash
curl -X POST http://localhost:3000/api/v1/meals/photos   -H "Authorization: Bearer <access_token>"   -F "photo=@comida.jpg"
```

**201 Created** — la foto queda en GridFS a nombre del usuario de la sesión:

```json
{ "id": "6acd4140ac968514f27322cd", "format": "jpeg", "size_bytes": 134 }
```

| Caso | Respuesta |
|---|---|
| Sin campo `photo` o archivo vacío | `400 VALIDATION_ERROR` con `fields.photo` |
| El cuerpo no es `multipart/form-data` válido | `400 INVALID_BODY` |
| Sin sesión / token inválido | `401 UNAUTHORIZED` |
| Cuenta de coach | `403 FORBIDDEN_ROLE` |
| Más de 5 MiB | `413 PHOTO_TOO_LARGE` |
| No es JPEG ni PNG | `415 UNSUPPORTED_PHOTO_TYPE` |

El límite de cuerpo de esta ruta es 6 MiB (5 MiB de foto + 1 MiB de margen para el multipart); un cuerpo mayor también
responde `413 PHOTO_TOO_LARGE` con el formato de la API. El `id` es el que usarán HU-07 (estimación) y HU-09 (registro).

### POST `/meals/estimate` (HU-07)

Cabecera `Authorization: Bearer <access_token>`. **Solo rol `user`**. Cuerpo `{ "photo_id": "<id de POST /meals/photos>" }`.
Manda la foto al servicio de reconocimiento de alimentos mediante el adaptador de `services/food_recognition/` (RNF-13):
el proveedor se elige con `FOOD_PROVIDER` (`simulator` por defecto; `gemini` en el ambiente desplegado, decisión de
[TEC-02](../docs/spikes/TEC-02-reconocimiento-de-alimentos.md)) y cambiarlo no toca handlers ni rutas. No guarda nada:
el usuario revisa y corrige los valores antes de guardar (HU-08 / HU-09).

**200 OK** — alimentos identificados (RF-06) y totales, redondeados a un decimal:

```json
{
  "photo_id": "6acd4140ac968514f27322cd",
  "foods": [
    { "name": "Arroz blanco cocido", "grams": 150.0, "calories_kcal": 195.0, "protein_g": 4.0, "fat_g": 0.4 },
    { "name": "Pechuga de pollo a la plancha", "grams": 120.0, "calories_kcal": 198.0, "protein_g": 37.2, "fat_g": 4.3 },
    { "name": "Ensalada verde", "grams": 80.0, "calories_kcal": 20.0, "protein_g": 1.0, "fat_g": 0.2 }
  ],
  "totals": { "calories_kcal": 413.0, "protein_g": 42.2, "fat_g": 4.9 }
}
```

`grams` puede ser `null` si el servicio no estima la porción. `foods` nunca está vacía.

| Caso | Respuesta |
|---|---|
| Falta `photo_id` o está vacío | `400 VALIDATION_ERROR` con `fields.photo_id` |
| El cuerpo no es JSON válido | `400 INVALID_BODY` |
| Sin sesión / token inválido | `401 UNAUTHORIZED` |
| Cuenta de coach | `403 FORBIDDEN_ROLE` |
| La foto no existe, el id está mal formado o es de otro usuario | `404 PHOTO_NOT_FOUND` |
| El servicio no reconoce comida en la foto | `422 FOOD_NOT_RECOGNIZED` → la app ofrece la captura manual (CU-01 flujo 4a) |
| El servicio externo falla (HTTP de error, cuota, respuesta inesperada) | `502 FOOD_PROVIDER_ERROR` |
| El servicio no responde dentro de `FOOD_PROVIDER_TIMEOUT_SECS` (máximo 10 s, RNF-01) | `504 FOOD_PROVIDER_TIMEOUT` |

El detalle de un `502`/`504` solo va al log del servidor (`[reconocimiento de alimentos] ...`); nunca al cliente.
Para probar la app contra cada caso sin red, levanta el backend con `FOOD_SIMULATOR_MODE=not_recognized`, `error` o `timeout`.

### Registros de comida — `/meals` (HU-09)

Cabecera `Authorization: Bearer <access_token>`. **Solo rol `user`** en los tres métodos: sin sesión `401 UNAUTHORIZED`,
una cuenta de coach `403 FORBIDDEN_ROLE` (RN-07; el coach consulta las comidas de un cliente con HU-25, solo lectura).

**Zona horaria del día:** la fecha y hora (`eaten_at`, UTC) las pone el servidor al guardar, y el día del registro
(`date`) se calcula en ese momento con la zona fija `APP_UTC_OFFSET` (por defecto `-06:00`, centro de México). Así una
cena a las 19:30 del 16 queda en `2026-10-16` aunque en UTC ya sea el 17, y el usuario y su coach ven el mismo día.
`?date=` filtra por ese campo.

**POST `/meals`** — guarda los valores **finales** (los que el usuario confirmó tras revisar la estimación):

```json
{ "photo_id": "6acd4140ac968514f27322cd", "calories_kcal": 413, "protein_g": 42.2, "fat_g": 4.9 }
```

| Campo | Regla |
|---|---|
| `photo_id` | Opcional (captura manual sin foto: omítelo o `null`). Si viene: texto, id de una foto **propia** de `POST /meals/photos` que no esté en otro registro |
| `calories_kcal` | Obligatorio. Número de 0 a 10 000 |
| `protein_g`, `fat_g` | Obligatorios. Número de 0 a 1 000 |

**201 Created**

```json
{
  "id": "6ad0a1b2c3d4e5f6a7b8c9d0",
  "photo_id": "6acd4140ac968514f27322cd",
  "eaten_at": "2026-10-17T01:30:00Z",
  "date": "2026-10-16",
  "calories_kcal": 413.0,
  "protein_g": 42.2,
  "fat_g": 4.9
}
```

`photo_id` es `null` en una captura manual. HU-08 agregará los valores estimados junto a estos finales.

**GET `/meals?date=2026-10-16`** → `200` con la lista de registros (misma forma) del usuario de la sesión en ese día, del
más antiguo al más reciente; `[]` si no hay registros.

**DELETE `/meals/{id}`** → `204 No Content`. Elimina el registro y su foto del almacenamiento (TEC-13).

| Caso | Respuesta |
|---|---|
| Valores ausentes, no numéricos, negativos o fuera de rango; `photo_id` que no es texto | `400 VALIDATION_ERROR` con cada campo en `fields` |
| `date` ausente o con formato distinto de `YYYY-MM-DD` | `400 VALIDATION_ERROR` con `fields.date` |
| El cuerpo no es JSON válido | `400 INVALID_BODY` |
| Sin sesión / token inválido | `401 UNAUTHORIZED` |
| Cuenta de coach | `403 FORBIDDEN_ROLE` |
| La foto no existe, el id está mal formado o es de otro usuario | `404 PHOTO_NOT_FOUND` |
| El registro a eliminar no existe, el id está mal formado o es de otro usuario | `404 MEAL_NOT_FOUND` (no se revela que existe) |
| La foto ya está en otro registro | `409 PHOTO_ALREADY_USED` con `fields.photo_id` |

### POST `/dev/seed/coach-links` (HU-05)

Solo existe con `APP_ENV=development`; en cualquier otro ambiente la ruta no se monta (`404`). Sin autenticación.
Cuerpo `{ "coach_id", "user_id" }` (ids de cuentas existentes con rol `coach` y `user`). **201** con la vinculación
`active` (la crea o la reactiva). Errores: `400 VALIDATION_ERROR`.

### GET `/coach/test`

Misma autenticación que `/auth/me`. **200 OK** `{ "user_id", "role" }` para coaches; `403 FORBIDDEN_ROLE` para `user`.

### Catálogo de ejercicios — `/exercises` (TEC-09)

Cabecera `Authorization: Bearer <access_token>`. Disponible para roles `user` y `coach`.

**GET** con filtros opcionales por parámetros de consulta (query params):
- `muscle_group`: `"chest"`, `"back"`, `"legs"`, `"shoulders"`, `"arms"`, `"core"`
- `level`: `"beginner"`, `"intermediate"`, `"advanced"`

Ejemplo: `GET /api/v1/exercises?muscle_group=chest&level=beginner`

Respuesta **200 OK**:
```json
[
  {
    "id": "6ac6...",
    "name": "Flexiones de pecho",
    "muscle_group": "chest",
    "equipment": "bodyweight",
    "level": "beginner",
    "created_at": "2026-10-13T12:00:00Z"
  }
]
```

### POST `/dev/seed/exercises` (TEC-09)

Solo existe con `APP_ENV=development`; en cualquier otro ambiente la ruta no se monta (`404`). Sin autenticación.
Ejecuta la siembra del catálogo inicial en la base de datos de manera reproducible e idempotente (no duplica ejercicios).

**201 Created**:
```json
{
  "message": "Catálogo de ejercicios cargado correctamente",
  "count": 18
}
```

---

## 🏋️‍♂️ Carga del Catálogo Inicial de Ejercicios (TEC-09)

Catálogo base de ejercicios que usan las rutinas del coach (HU-18) y el motor de reglas (TEC-10 / RF-14).
Sebastián lo trabaja en paralelo con la vinculación. Es la tercera en salir del sprint si en la revisión del día 5 la ruta crítica va atrasada; fecha límite: día 7 (20/10).

El catálogo inicial de ejercicios cuenta con un mínimo acordado en el Sprint Planning de **18 ejercicios**,
cubriendo exhaustivamente todas las 18 combinaciones de 6 grupos musculares (`chest`, `back`, `legs`, `shoulders`, `arms`, `core`)
y 3 niveles de dificultad (`beginner`, `intermediate`, `advanced`, con los mismos valores que el perfil de usuario),
garantizando que el motor de reglas (TEC-10 / RF-14) pueda generar una rutina válida en cualquier caso.

La carga es **reproducible e idempotente**: ejecutar el proceso dos o más veces actualiza la información pero **no duplica registros**
(gracias al índice único sobre `name` y a la operación `find_one_and_update` con `upsert: true`).

### Ejecución Local

1. **Binario de Cargo:**
   ```bash
   cd backend
   cargo run --bin seed_exercises
   ```
2. **Atajo Bash:**
   ```bash
   scripts/dev.sh seed-exercises
   ```

### Ejecución en Ambiente Desplegado

El ambiente desplegado corre con `APP_ENV=production`, así que `/dev/seed/*` responde 404 ahí (ver [Despliegue](#-despliegue)).

1. **Vía API REST:**
   Si la API está desplegada con `APP_ENV=development`:
   ```bash
   curl -X POST https://<tu-api-desplegada>/api/v1/dev/seed/exercises
   ```
2. **Vía Binario en Contenedor / Tarea de Despliegue:**
   ```bash
   MONGO_URI="mongodb+srv://..." DB_NAME="macrofit_prod" cargo run --bin seed_exercises
   ```

---

## 🚀 Despliegue

El backend y su base de datos corren en [Railway](https://railway.app), proyecto `macrofit`, ambiente `production`:

| Servicio | Qué es |
|---|---|
| `backend` | Imagen construida con [Dockerfile](Dockerfile); URL pública con HTTPS |
| `MongoDB` | Base de datos del ambiente, separada de la de desarrollo de cada integrante. El backend la alcanza por la red privada de Railway |

URL: `https://backend-production-3f327.up.railway.app` (health: `/api/v1/health`).

### Variables

Se configuran en el servicio `backend` de Railway; ninguna está en el repositorio.

| Variable | Valor en el ambiente desplegado |
|---|---|
| `MONGO_URI` | Referencia al servicio de Mongo: `${{MongoDB.MONGO_URL}}` |
| `DB_NAME` | `macrofit_prod` |
| `JWT_SECRET` | Cadena aleatoria propia de este ambiente |
| `APP_ENV` | `production` (no `development`: así `/dev/seed/*` no se monta y responde 404) |
| `FOOD_PROVIDER`, `GEMINI_API_KEY`, `GEMINI_MODEL` | `gemini`, la llave de Google AI Studio del proyecto y el modelo elegido (HU-07, decisión de TEC-02) |
| `RAILWAY_DOCKERFILE_PATH` | `backend/Dockerfile` (el contexto de build es la raíz del repo) |

### Desplegar una versión nueva

Con la [CLI de Railway](https://docs.railway.com/cli) instalada y la sesión iniciada (`railway login`):

```bash
railway link            # una vez: proyecto macrofit, ambiente production
railway up --service backend --ci
```

Desde la raíz del repositorio. `railway up` sube el código local y espera a que el healthcheck (`/api/v1/health`, definido en [../railway.json](../railway.json)) responda. Después de desplegar:

```bash
curl https://backend-production-3f327.up.railway.app/api/v1/health                 # 200
curl -X POST https://backend-production-3f327.up.railway.app/api/v1/dev/seed/coach-links   # 404
```

Para probar la API en este ambiente, importa `postman/MacroFit.deployed.postman_environment.json` ([postman/README.md](postman/README.md)).

### Límites del plan

El plan gratuito de Railway funciona con un crédito de uso limitado, no con recursos ilimitados (riesgo S-05). Revisa el consumo en el panel del proyecto (*Usage*) antes de las pruebas del Sprint 3. Si se agota, los servicios se detienen hasta renovar el crédito o cambiar de plan.

### Datos de prueba en el ambiente desplegado

Las carpetas de Postman que dependen de `/dev/seed` (HU-05 *Metas por coach* y TEC-09 *Catálogo de ejercicios*) fallan contra este ambiente porque esa ruta no existe en producción. Es lo esperado. El resto de la colección pasa. El catálogo de ejercicios se puede cargar con `cargo run --bin seed_exercises` apuntando `MONGO_URI` a la base desplegada.

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
| `INVITE_CODE_NOT_FOUND` | 404 | El código de invitación no existe o ya no está vigente |
| `PHOTO_NOT_FOUND` | 404 | La foto no existe o la cuenta no puede verla (no se distingue) |
| `MEAL_NOT_FOUND` | 404 | El registro de comida no existe o es de otra cuenta (no se distingue, HU-09) |
| `FOOD_NOT_RECOGNIZED` | 422 | El servicio de reconocimiento no encontró comida en la foto (HU-07): captura manual |
| `USER_ALREADY_LINKED` | 409 | El usuario ya tiene una vinculación activa con un coach |
| `EMAIL_ALREADY_EXISTS` | 409 | El correo ya está registrado |
| `PROFILE_ALREADY_EXISTS` | 409 | El usuario ya tiene un perfil (se edita con `PATCH`) |
| `PHOTO_ALREADY_USED` | 409 | La foto ya está en otro registro de comida (HU-09) |
| `PHOTO_TOO_LARGE` | 413 | La foto supera 5 MiB (o el cuerpo de la subida supera el límite de la ruta) |
| `UNSUPPORTED_PHOTO_TYPE` | 415 | La foto no es JPEG ni PNG (se revisa el contenido) |
| `FOOD_PROVIDER_ERROR` | 502 | El servicio de reconocimiento de alimentos falló (HU-07) |
| `FOOD_PROVIDER_TIMEOUT` | 504 | El servicio de reconocimiento de alimentos no respondió en el tiempo de espera (HU-07, máximo 10 s) |
| `INTERNAL_ERROR` | 500 | Error inesperado (el detalle solo va al log del servidor) |

---

## 🗄️ Base de datos

Ver [src/models/README.md](src/models/README.md) para el esquema de cada colección.

### Fotos de comidas (TEC-13)

Se suben con `POST /meals/photos` (HU-06) y se guardan en **GridFS**, en la misma base (`meal_photos.files` y `meal_photos.chunks`), así que **no requieren
variables de entorno ni servicios nuevos**. Solo JPEG y PNG (detectados por contenido) y máximo 5 MB. Las lee su dueño
o su coach con vinculación activa; solo el dueño las elimina. Decisión y reglas en
[src/services/README.md](src/services/README.md#fotos-de-comidas-tec-13).

```js
db.meal_photos.files.find({}, { length: 1, metadata: 1, uploadDate: 1 }).sort({ uploadDate: -1 }).limit(3)
```

Evidencia de que la contraseña se guarda solo como hash (`mongosh`):

```js
db.users.find({}, { name: 1, email: 1, password_hash: 1, role: 1 }).sort({ created_at: -1 }).limit(3)
db.users.countDocuments({ password: { $exists: true } })   // debe ser 0

// Sesiones: solo se guarda el hash del refresh token
db.refresh_tokens.find({}, { _id: 0 }).sort({ created_at: -1 }).limit(3)
```
