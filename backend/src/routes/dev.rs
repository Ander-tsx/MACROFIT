//! Datos de prueba. Solo se monta con `APP_ENV=development` (ver `routes::api_router`).

use axum::{Json, Router, extract::State, http::StatusCode, routing::post};
use serde::{Deserialize, Serialize};

use crate::error::{ApiJson, AppError};
use crate::models::coach_link::{CoachLink, LinkStatus};
use crate::services::coach_links::{self, SeedLinkInput};
use crate::state::AppState;

pub fn router() -> Router<AppState> {
    Router::new().route("/dev/seed/coach-links", post(seed_coach_link_handler))
}

#[derive(Debug, Deserialize)]
pub struct SeedCoachLinkRequest {
    pub coach_id: Option<String>,
    pub user_id: Option<String>,
}

#[derive(Debug, Serialize)]
pub struct CoachLinkResponse {
    pub id: String,
    pub coach_id: String,
    pub user_id: String,
    pub status: LinkStatus,
    pub created_at: String,
}

impl From<CoachLink> for CoachLinkResponse {
    fn from(link: CoachLink) -> Self {
        Self {
            id: link.id.to_hex(),
            coach_id: link.coach_id.to_hex(),
            user_id: link.user_id.to_hex(),
            status: link.status,
            created_at: link.created_at.try_to_rfc3339_string().unwrap_or_default(),
        }
    }
}

/// HU-05 — `POST /api/v1/dev/seed/coach-links`. Vincula a un coach con un usuario (solo desarrollo).
async fn seed_coach_link_handler(
    State(state): State<AppState>,
    ApiJson(body): ApiJson<SeedCoachLinkRequest>,
) -> Result<(StatusCode, Json<CoachLinkResponse>), AppError> {
    let link = coach_links::seed_link(
        &state.db,
        SeedLinkInput {
            coach_id: body.coach_id,
            user_id: body.user_id,
        },
    )
    .await?;
    Ok((StatusCode::CREATED, Json(link.into())))
}
