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
- **Todo endpoint se documenta en OpenAPI** al terminarse (sección siguiente). Las pruebas de `openapi.rs` fallan
  si un endpoint del catálogo no está documentado o si su contrato no coincide.

## Documentar un endpoint en OpenAPI (TEC-14)

La especificación (`GET /api/v1/openapi.json`, Swagger UI en `/api/v1/docs`) se **genera desde el código** con
[`utoipa`](https://docs.rs/utoipa/5): nunca se escribe a mano. Para un endpoint nuevo:

1. **DTOs**: agrega `ToSchema` a cada DTO de entrada y de salida (y a los enums que usen, p. ej. en `models/`).
   Los comentarios `///` de los campos aparecen como su descripción en Swagger UI, así que escríbelos para la app.

   ```rust
   #[derive(Debug, Deserialize, ToSchema)]
   #[schema(description = "Peso a registrar. Todos los campos son obligatorios.")]
   pub struct WeightRequest {
       /// De 35 a 250 kg (rango de TEC-12).
       #[schema(value_type = f64, required = true, example = 72.5)]
       pub weight_kg: Option<f64>,
   }
   ```

   - Campos obligatorios: siguen siendo `Option<T>` (regla de validación por campo), pero se marcan con
     `#[schema(value_type = T, required = true)]` para que el contrato los muestre obligatorios y no `null`.
   - Enumerados que llegan como `String`: `#[schema(value_type = MiEnum, required = true)]`.
   - `serde_json::Value`: `#[schema(value_type = i32)]` (o el tipo que espera el contrato).
   - Fechas como texto: `#[schema(format = Date)]` (`YYYY-MM-DD`) o `#[schema(format = DateTime)]` (RFC 3339).
   - Si el comentario `///` del struct es interno, sobrescríbelo con `#[schema(description = "...")]`.

2. **Handler**: anota la operación. La ruta va **sin** `/api/v1` (el servidor de la especificación ya lo incluye)
   y los parámetros con `{nombre}`.

   ```rust
   #[utoipa::path(
       post,
       path = "/users/me/weights",
       tag = "Progreso",
       summary = "Registra un peso",
       security(("bearer_auth" = ["user"])),
       request_body = WeightRequest,
       responses(
           (status = 201, description = "Peso registrado", body = WeightResponse),
           (status = 400, description = "`VALIDATION_ERROR` o `INVALID_BODY`", body = ErrorResponse),
           (status = 401, description = "`UNAUTHORIZED` o `TOKEN_REVOKED`", body = ErrorResponse),
           (status = 403, description = "`FORBIDDEN_ROLE` (cuenta `coach`)", body = ErrorResponse),
       )
   )]
   pub async fn create_weight_handler(/* ... */) -> Result<(StatusCode, Json<WeightResponse>), AppError> {
   ```

   - **Seguridad según el extractor**: `AuthenticatedUser` → `security(("bearer_auth" = []))`; `UserOnly` →
     `["user"]`; `CoachOnly` → `["coach"]`; ruta pública → sin `security`.
   - **Errores**: cada respuesta 4xx usa `body = ErrorResponse` (`crate::error::ErrorResponse`, el único formato de
     error) y su descripción nombra los códigos entre comillas invertidas. No documentes `500`: lo cubre la
     descripción general de la API.
   - Parámetros de ruta: `params(("clientId" = String, Path, description = "..."))`.
   - Listas: `body = [GoalResponse]`. Sin cuerpo (`204`): solo `description`.
   - El handler debe ser `pub` para que `openapi.rs` lo encuentre.

3. **Registro**: agrega el handler a `paths(...)` de `ApiDoc` en `openapi.rs` (o de `DevApiDoc` si es una ruta de
   `dev.rs`) y, si es un módulo nuevo, su `tag` en `tags(...)`.

4. **Pruebas**: agrega la fila del endpoint a `CATALOG` en las pruebas de `openapi.rs` (método, ruta, rol y códigos
   de estado) y a `catalog` en `postman/openapi/` (*Especificación OpenAPI*). `cargo test` comprueba que el
   endpoint esté documentado, que exista en el router, que use `ErrorResponse` y que declare su rol.

5. Revisa el resultado en `http://localhost:3000/api/v1/docs` con `cargo run`.

## Archivos

| Archivo | Rutas |
|---|---|
| `mod.rs` | `API_PREFIX`, `/health` y composición de routers |
| `openapi.rs` | `/openapi.json` y `/docs` (TEC-14): `ApiDoc` con los `paths(...)` de todos los handlers, esquema `bearer_auth` y pruebas del contrato |
| `legal.rs` | `/legal/privacy` (TEC-07) |
| `auth.rs` | `/auth/register` (HU-01), `/auth/login`, `/auth/refresh`, `/auth/logout`, `/auth/me` (HU-02), `/coach/test` (TEC-05) |
| `goals.rs` | `/users/me/goals` y `/users/me/goals/current` (HU-04, `UserOnly`); `/coach/clients` y `/coach/clients/{clientId}/goals` (HU-05, `CoachOnly`) |
| `dev.rs` | `/dev/seed/coach-links` (HU-05): solo se monta con `APP_ENV=development` |
| `profile.rs` | `/users/me/profile` POST/GET/PATCH (HU-03), solo rol `user` (`UserOnly`) |
| `coach_invite_codes.rs` | `/coach/invite-code` GET y POST `/coach/invite-code/regenerate` (HU-12), solo rol `coach` (`CoachOnly`) |
| `coach_links.rs` | `/users/me/coach-link` POST (HU-13), solo rol `user` (`UserOnly`) |
| `weights.rs` | `/users/me/weights` POST/GET (HU-21), solo rol `user` (`UserOnly`) |