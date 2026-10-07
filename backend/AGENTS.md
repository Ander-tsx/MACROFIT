# AGENTS.md — Backend MacroFit

Instrucciones para cualquier agente de IA (Claude Code, Codex, Copilot, Cursor, etc.) que modifique `backend/`.
Son obligatorias. Si algo aquí contradice a otro documento, avisa a la persona en lugar de elegir por tu cuenta.

Documentación de referencia (léela antes de tocar una carpeta):

| Documento | Contenido |
|---|---|
| [README.md](README.md) | Configuración, catálogo de endpoints, modelo de sesión, formato y códigos de error |
| [src/README.md](src/README.md) | Mapa de módulos y responsabilidades por capa |
| `src/<carpeta>/README.md` | Reglas de `routes/`, `services/`, `models/`, `auth/` |
| [postman/README.md](postman/README.md) | Colecciones por módulo, `build.js`, convenciones de tests |
| [../product_backlog_macrofit.md](../product_backlog_macrofit.md) | Historias (`HU-XX`) y tareas técnicas (`TEC-XX`) |
| [../CONTRIBUTING.md](../CONTRIBUTING.md) | Ramas, commits y pull requests |

---

## 1. Reglas de colaboración

1. **No asumas decisiones de lógica que no estén declaradas.** Si la historia, el código o estos documentos no
   definen algo que impacta el diseño (contrato de la API, códigos de estado, formato de respuesta, reglas de negocio,
   seguridad, esquema de datos, alcance), **pregunta antes de implementar** y ofrece una opción recomendada.
   Las decisiones pequeñas (nombres internos, mensajes, límites razonables, organización del código) tómalas tú
   y menciónalas en el resumen final.
2. **Alcance**: haz lo que pide la historia. Si detectas algo fuera de alcance, señálalo; no lo implementes sin permiso.
3. **Lo que no se puede probar en este entorno** (capturas para el PR, pruebas que requieren esperar la expiración real
   de un token, Flutter, etc.) se reporta como pendiente; nunca se da por hecho.
4. **No hagas commit, push ni PR** salvo que la persona lo pida. Si lo pide, sigue `../CONTRIBUTING.md`.
5. **Idioma**: textos al cliente, comentarios, README y nombres de tests en **español**; identificadores de código en inglés.

## 2. Stack

- Rust **edición 2024**, Axum **0.7** sobre Tokio, driver oficial de MongoDB **3.x**.
- Contraseñas: `argon2` (Argon2id, feature `std` obligatoria para `OsRng`).
- Sesión: `jsonwebtoken` (access token HS256), `sha2` + `rand` (refresh tokens opacos).
- Configuración: `dotenvy` lee `.env`; **no sobrescribe variables ya definidas** en el entorno.

## 3. Arquitectura

```
main.rs ─▶ routes/ ─▶ services/ ─▶ models/
              │            │
              └──▶ auth/ ◀─┘        error.rs · validation.rs · config.rs · state.rs · db.rs (transversales)
```

| Capa | Hace | Nunca |
|---|---|---|
| `routes/<modulo>.rs` | Rutas, DTOs de entrada/salida, handlers delgados | Consultar Mongo o contener reglas de negocio |
| `services/<modulo>.rs` | Validación del caso de uso, reglas, acceso a Mongo | Usar tipos HTTP (`StatusCode`, `Json`) |
| `models/<coleccion>.rs` | Struct del documento y constante del nombre de colección | Serializarse hacia el cliente |
| `auth/` | JWT, refresh tokens, hash de contraseñas, extractores `AuthenticatedUser` / `CoachOnly` | Lógica de un dominio concreto |
| `error.rs` | `AppError` → `{ "error": { code, message, fields } }`; extractor `ApiJson` | — |
| `db.rs` | Conexión y **todos** los índices (`ensure_indexes`) | — |
| `config.rs` | Única lectura de variables de entorno | — |

## 4. Reglas de código (no negociables)

1. Todas las rutas cuelgan de **`/api/v1`** (`routes::API_PREFIX`). Un módulo nuevo expone `router()` y se une con `merge` en `routes::api_router`.
2. Todo handler devuelve **`Result<_, AppError>`**. Nunca construyas JSON de error a mano.
3. Lee cuerpos con **`ApiJson<T>`**, nunca con `axum::Json` como extractor.
4. DTOs de entrada con **campos `Option<T>`**; valores enumerados (como `role`) como `String` y se validan en el servicio.
5. **Valida todos los campos a la vez** y devuelve `AppError::Validation(FieldErrors)` con cada campo inválido.
   Separa una función pura `validate_xxx` (probada sin BD) de la función async que persiste.
6. Respuestas con **DTOs propios** (`impl From<Modelo>`). Nunca devuelvas un modelo de Mongo ni `password_hash`.
7. Correos siempre por `validation::normalize_email` antes de guardar o buscar.
8. Hash/verificación de contraseñas dentro de **`tokio::task::spawn_blocking`**.
9. Unicidad garantizada por **índice único** en `db.rs`; traduce el error de clave duplicada (`11000`) al `AppError` correspondiente.
10. Roles en minúsculas: `"user"` / `"coach"` (`models::user::Role`).
11. Rutas protegidas: argumento `AuthenticatedUser` (cualquier sesión) o `CoachOnly` (solo coach). No reimplementes la verificación del token.
12. Secretos y duraciones desde `state.tokens` (`TokenConfig`); `std::env::var` solo en `config.rs`.
13. Errores inesperados con `AppError::internal(err)`: el detalle va al log, el cliente recibe `INTERNAL_ERROR`.
14. Un código de error nuevo = variante en `AppError` + fila en la tabla de códigos de `README.md`.
15. Pendientes de otra historia: `// TODO(ID-BACKLOG): qué falta y qué cambiar` (p. ej. `TODO(TEC-07)`).
16. No uses `unwrap()`/`expect()` en código que atiende peticiones. Se permiten en el arranque (`main.rs`, `config.rs`,
    `db.rs`), en valores estáticos que no pueden fallar en la práctica (p. ej. `DUMMY_HASH`) y en tests.

## 5. Seguridad (no negociable)

- **Nunca** leas, muestres, registres ni subas el contenido de `.env`. Solo `.env.example` (sin secretos) se versiona.
- Nunca registres contraseñas, hashes ni tokens.
- Contraseñas solo como hash Argon2id; refresh tokens solo como SHA-256 (`refresh_tokens.token_hash`).
- Login: mismo código y mensaje (`INVALID_CREDENTIALS`) para correo inexistente y contraseña incorrecta; se mantiene el hash ficticio que iguala tiempos.
- Modelo de sesión (HU-02): access token de corta duración con `sid`; el middleware comprueba que la sesión siga activa;
  rotación de refresh token en cada renovación; reutilizar un token revocado revoca la sesión completa.
  No cambies ninguno de estos comportamientos sin que la persona lo apruebe.
- No apuntes pruebas a la base de datos compartida (Atlas) sin permiso. Usa una base temporal (sección 7).

## 6. Comandos

Desde `backend/`:

| Comando | Para qué |
|---|---|
| `cargo run` | Levantar la API (usa `.env`) |
| `cargo fmt` / `cargo fmt --check` | Formato |
| `cargo clippy --all-targets -- -D warnings` | Lint sin avisos |
| `cargo test` | Pruebas unitarias |
| `node postman/build.js` | Regenerar la colección combinada tras editar un módulo de Postman |
| `node postman/build.js --check` | Verificar que el combinado está al día |
| `npx newman run postman/MacroFit.postman_collection.json -e postman/MacroFit.postman_environment.json` | Ejecutar la colección completa |

## 7. Verificación obligatoria antes de dar una tarea por terminada

1. `cargo fmt --check`, `cargo clippy --all-targets -- -D warnings` y `cargo test` sin errores ni avisos.
2. `node postman/build.js --check` al día.
3. **Pruebas de API contra una base temporal** (no la de `.env`). Las variables de entorno tienen prioridad sobre `.env`:

   ```bash
   cargo build
   MONGO_URI=mongodb://localhost:27017 DB_NAME=macrofit_check PORT=3077 ./target/debug/backend &
   npx newman run postman/MacroFit.postman_collection.json \
     -e postman/MacroFit.postman_environment.json --env-var baseUrl=http://localhost:3077
   ```

   - La colección debe pasar **dos veces seguidas** (prueba que los datos son únicos por ejecución).
   - Si la historia guarda datos sensibles, revisa el documento en Mongo (`mongosh`) y confirma que no quedan en claro.
   - Al terminar: detén el servidor (en Windows `taskkill //F //IM backend.exe`) y borra la base temporal
     (`mongosh mongodb://localhost:27017/macrofit_check --eval 'db.dropDatabase()'`). Borra solo bases que creaste tú.
   - Si no hay MongoDB local, pide permiso antes de usar otra instancia.
4. Documentación actualizada (sección 8).
5. Resumen final: qué se hizo, decisiones menores tomadas, resultados de verificación y pendientes reales.

## 8. Al agregar o cambiar funcionalidad

1. **Colección nueva**: modelo en `src/models/`, índices en `db.rs::ensure_indexes`, esquema en `src/models/README.md`.
2. **Lógica**: `src/services/<modulo>.rs` con pruebas `#[cfg(test)]` en el mismo archivo (nombres en español que describan el caso).
3. **HTTP**: DTOs y handler en `src/routes/<modulo>.rs`, comentario `/// HU-XX — MÉTODO /api/v1/ruta`.
4. **Postman**: carpeta `HU-XX <Nombre>` en `postman/<modulo>/<modulo>.postman_collection.json` (mismo nombre que
   `src/routes/<modulo>.rs`), luego `node postman/build.js`. Nunca edites `postman/MacroFit.postman_collection.json` a mano.
   Reglas: tests de estado y estructura en cada request, scripts envueltos en `{ ... }`, correos únicos `@macrofit.test`,
   el entorno solo con `baseUrl`, y carpetas que invalidan datos compartidos con sufijo `· Cierre` (van al final).
   Un módulo nuevo se agrega a `MODULES` en `build.js`.
5. **Documentación**: catálogo de endpoints y códigos de error en `README.md`; tabla de archivos del README de cada carpeta tocada.
6. **Configuración nueva**: campo en `Config`/`TokenConfig`, variable en `.env.example` y fila en la tabla de `README.md`.

## 9. Trampas conocidas

- `dotenvy` no sobrescribe variables existentes: útil para pruebas, pero revisa tu entorno si algo "no toma" el `.env`.
- Newman comparte el ámbito entre scripts: dos `const` iguales en requests distintos rompen la ejecución si no van en `{ ... }`.
- El índice único de `users.email` hace fallar el arranque si ya hay correos repetidos; datos anteriores a HU-01/HU-02
  (roles `User`/`Coach`, hashes bcrypt) no son compatibles y deben limpiarse en desarrollo.
- `jsonwebtoken` tolera 60 s de desfase en `exp` por defecto.
- El reuso de un refresh token revoca la sesión completa: en Postman, prueba la rotación en una sesión auxiliar,
  nunca con los tokens que usan otras historias.
