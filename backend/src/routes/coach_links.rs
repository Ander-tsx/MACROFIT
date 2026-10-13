//! HU-13 — rutas de vinculación con el coach mediante código de invitación.

use axum::{
    Json, Router,
    extract::State,
    http::StatusCode,
    routing::post,
};
use serde::{Deserialize, Serialize};

use crate::auth::middleware::UserOnly;
use crate::error::{ApiJson, AppError};
use crate::services::coach_links::{self, LinkCoachInput};
use crate::state::AppState;

#[derive(Debug, Deserialize)]
pub struct LinkCoachRequest {
    pub invite_code: Option<String>,
}

#[derive(Debug, Serialize)]
pub struct CoachLinkResponse {
    pub id: String,
    pub coach_id: String,
    pub coach_name: String,
    pub coach_email: String,
    pub status: String,
}

/// HU-13 — POST /api/v1/users/me/coach-link
pub async fn link_coach_handler(
    UserOnly(auth): UserOnly,
    State(state): State<AppState>,
    ApiJson(req): ApiJson<LinkCoachRequest>,
) -> Result<(StatusCode, Json<CoachLinkResponse>), AppError> {
    let (link, coach) = coach_links::link_with_invite_code(
        &state.db,
        auth.user_id,
        LinkCoachInput {
            invite_code: req.invite_code,
        },
    )
    .await?;

    Ok((
        StatusCode::CREATED,
        Json(CoachLinkResponse {
            id: link.id.to_hex(),
            coach_id: coach.id_hex(),
            coach_name: coach.name,
            coach_email: coach.email,
            status: "active".to_string(),
        }),
    ))
}

pub fn router() -> Router<AppState> {
    Router::new().route("/users/me/coach-link", post(link_coach_handler))
}
