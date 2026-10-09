# `src/routes/` — capa HTTP

Un archivo por dominio. Cada archivo expone `pub fn router() -> Router<AppState>` y `mod.rs` los une
bajo `/api/v1` en `api_router()`.

## Reglas

- **Handlers delgados**: extraen datos, llaman a un servicio y convierten el resultado a un DTO de respuesta.
  Nada de consultas a Mongo ni reglas de negocio aquí.
- **Firma**: `async fn x_handler(...) -> Result<..., AppError>`.
- **Cuerpo JSON**: usar `ApiJson<T>` (de `crate::error`), nunca `axum::Json` como extractor.
  `axum::Json` sí se usa para *responder*.
- **DTOs de entrada** (`XxxRequest`): todos los campos `Option<T>` para poder señalar campo por campo lo que falta.
  Tipos libres (`String`) para valores enumerados como `role`, así un valor inválido se reporta como
  `VALIDATION_ERROR` del campo y no como `INVALID_BODY`.
- **DTOs de salida** (`XxxResponse`): structs propios con `impl From<Modelo>`. Nunca serializar un modelo de `models/`
  (expondría campos internos como `password_hash`).
- **Rutas protegidas**: agregar `AuthenticatedUser`, `CoachOnly` o `UserOnly` como argumento del handler (ver `src/auth/README.md`).
- **Códigos de estado**: `201` al crear (`(StatusCode::CREATED, Json(..))`), `204` sin cuerpo (`StatusCode::NO_CONTENT`, p. ej. logout), `200` en lo demás; los errores los decide `AppError`.
- Documentar cada handler con un comentario `/// HU-XX — MÉTODO /api/v1/ruta`.

## Archivos

| Archivo | Rutas |
|---|---|
| `mod.rs` | `API_PREFIX`, `/health` y composición de routers |
| `legal.rs` | `/legal/privacy` (TEC-07) |
| `auth.rs` | `/auth/register` (HU-01), `/auth/login`, `/auth/refresh`, `/auth/logout`, `/auth/me` (HU-02), `/coach/test` (TEC-05) |
| `profile.rs` | `/users/me/profile` POST/GET/PATCH (HU-03), solo rol `user` (`UserOnly`) |
