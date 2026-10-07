# `src/auth/` — seguridad transversal

Piezas de autenticación que usan todos los dominios. La lógica de registro/login vive en `services/auth.rs`.

| Archivo | Contenido |
|---|---|
| `password.rs` | `hash_password` / `verify_password` con **Argon2id** (parámetros por defecto del crate `argon2`, formato PHC con sal) |
| `jwt.rs` | Access token: `Claims { sub, role, sid, iat, exp }`, `generate_access_token`, `decode_access_token`. Duración y secreto desde `state.tokens` |
| `refresh.rs` | Refresh tokens opacos: `generate_refresh_token` (32 bytes aleatorios) y `hash_refresh_token` (SHA-256) |
| `middleware.rs` | Extractores `AuthenticatedUser` (401 `UNAUTHORIZED` sin token válido; 401 `TOKEN_REVOKED` si la sesión está cerrada) y `CoachOnly` (403 si el rol no es `coach`) |

## Proteger una ruta

```rust
// Cualquier usuario autenticado
pub async fn handler(user: AuthenticatedUser) -> Result<Json<...>, AppError> { ... }

// Solo coaches
pub async fn handler(CoachOnly(coach): CoachOnly) -> Result<Json<...>, AppError> { ... }
```

## Reglas

- Nunca registrar (log) contraseñas, hashes ni tokens.
- `hash_password` y `verify_password` son costosas: llamarlas dentro de `tokio::task::spawn_blocking`.
- No leer `JWT_SECRET` con `std::env::var`; usar `state.tokens.jwt_secret`.
- `AuthenticatedUser` hace una consulta a `refresh_tokens` por petición para saber si la sesión sigue activa. Es el
  precio de que el logout invalide el access token al instante; no lo quites sin cambiar la HU-02.
- La lógica de sesiones (rotación, reuso, logout) vive en `services/session.rs`; aquí solo están las primitivas.
- Un nuevo rol implica: variante en `models::user::Role`, su `parse` y, si aplica, un extractor nuevo aquí.
