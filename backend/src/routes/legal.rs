use axum::{Json, Router, routing::get};
use serde::Serialize;
use utoipa::ToSchema;

use crate::services::legal::{PRIVACY_NOTICE, PRIVACY_VERSION};
use crate::state::AppState;

pub fn router() -> Router<AppState> {
    Router::new().route("/legal/privacy", get(privacy_handler))
}

/// Aviso de privacidad vigente.
#[derive(Debug, Serialize, ToSchema)]
pub struct PrivacyNoticeResponse {
    /// Versión vigente; se guarda en la cuenta al registrarse.
    #[schema(example = "1.0")]
    pub version: &'static str,
    /// Texto completo en Markdown.
    #[schema(example = "# Aviso de privacidad\n\n...")]
    pub content: &'static str,
}

/// TEC-07 — `GET /api/v1/legal/privacy`. Público: se muestra antes de registrarse.
#[utoipa::path(
    get,
    path = "/legal/privacy",
    tag = "Aviso de privacidad",
    summary = "Aviso de privacidad vigente",
    description = "Versión vigente y texto completo (Markdown). Público: la app lo muestra antes del registro.",
    responses(
        (status = 200, description = "Aviso vigente", body = PrivacyNoticeResponse),
    )
)]
pub async fn privacy_handler() -> Json<PrivacyNoticeResponse> {
    Json(PrivacyNoticeResponse {
        version: PRIVACY_VERSION.as_str(),
        content: PRIVACY_NOTICE,
    })
}
