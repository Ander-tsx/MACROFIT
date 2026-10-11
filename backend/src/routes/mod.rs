use axum::{Router, routing::get};

use crate::state::AppState;

pub mod auth;
pub mod dev;
pub mod goals;
pub mod legal;
pub mod profile;

/// Prefijo común de la API. Una versión nueva incompatible se monta en `/api/v2`.
pub const API_PREFIX: &str = "/api/v1";

/// Une los routers de cada módulo bajo `/api/v1`. Las rutas de `dev` solo se montan en desarrollo.
pub fn api_router(dev_mode: bool) -> Router<AppState> {
    let mut v1 = Router::new()
        .route("/health", get(|| async { "API MacroFit OK" }))
        .merge(auth::router())
        .merge(legal::router())
        .merge(profile::router())
        .merge(goals::router());
    if dev_mode {
        v1 = v1.merge(dev::router());
    }

    Router::new().nest(API_PREFIX, v1)
}
