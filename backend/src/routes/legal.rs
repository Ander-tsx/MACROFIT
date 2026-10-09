use axum::{Json, Router, routing::get};
use serde::Serialize;

use crate::services::legal::{PRIVACY_NOTICE, PRIVACY_VERSION};
use crate::state::AppState;

pub fn router() -> Router<AppState> {
    Router::new().route("/legal/privacy", get(privacy_handler))
}

/// Aviso de privacidad vigente.
#[derive(Debug, Serialize)]
pub struct PrivacyNoticeResponse {
    pub version: &'static str,
    /// Texto completo en Markdown.
    pub content: &'static str,
}

/// TEC-07 — `GET /api/v1/legal/privacy`. Público: se muestra antes de registrarse.
pub async fn privacy_handler() -> Json<PrivacyNoticeResponse> {
    Json(PrivacyNoticeResponse {
        version: PRIVACY_VERSION.as_str(),
        content: PRIVACY_NOTICE,
    })
}
