use axum::{Router, routing::get};

use crate::state::AppState;

pub mod auth;
pub mod coach_invite_codes;
pub mod dev;
pub mod goals;
pub mod legal;
pub mod openapi;
pub mod profile;

/// Prefijo común de la API. Una versión nueva incompatible se monta en `/api/v2`.
pub const API_PREFIX: &str = "/api/v1";

/// Une los routers de cada módulo bajo `/api/v1`. Las rutas de `dev` solo se montan en desarrollo.
/// La documentación OpenAPI (`/api/v1/docs` y `/api/v1/openapi.json`) se monta siempre.
pub fn api_router(dev_mode: bool) -> Router<AppState> {
    let mut v1 = Router::new()
        .route("/health", get(health_handler))
        .merge(auth::router())
        .merge(coach_invite_codes::router())
        .merge(legal::router())
        .merge(profile::router())
        .merge(goals::router());
    if dev_mode {
        v1 = v1.merge(dev::router());
    }

    Router::new()
        .nest(API_PREFIX, v1)
        .merge(openapi::router(dev_mode))
}

/// TEC-05 — `GET /api/v1/health`. Comprueba que el servidor responde.
#[utoipa::path(
    get,
    path = "/health",
    tag = "Servicio",
    summary = "Estado del servidor",
    responses(
        (status = 200, description = "Servidor activo", body = String, content_type = "text/plain", example = "API MacroFit OK"),
    )
)]
pub async fn health_handler() -> &'static str {
    "API MacroFit OK"
}
