use axum::{Router, routing::get};

use crate::state::AppState;

pub mod auth;
pub mod goals;
pub mod legal;
pub mod profile;

/// Prefijo común de la API. Una versión nueva incompatible se monta en `/api/v2`.
pub const API_PREFIX: &str = "/api/v1";

/// Une los routers de cada módulo bajo `/api/v1`.
pub fn api_router() -> Router<AppState> {
    let v1 = Router::new()
        .route("/health", get(|| async { "API MacroFit OK" }))
        .merge(auth::router())
        .merge(legal::router())
        .merge(profile::router())
        .merge(goals::router());

    Router::new().nest(API_PREFIX, v1)
}
