//! HU-12 — rutas del código de invitación del coach (solo rol coach).

use axum::{
    Json, Router,
    extract::State,
    routing::{get, post},
};
use serde::{Deserialize, Serialize};

use crate::error::AppError;
use crate::auth::middleware::CoachOnly;
use crate::services::coach_invite_codes;
use crate::state::AppState;

#[derive(Debug, Serialize, Deserialize)]
pub struct InviteCodeResponse {
    pub code: String,
}

/// `GET /coach/invite-code`: devuelve el código del coach; lo crea si no existe.
pub async fn get_invite_code_handler(
    CoachOnly(auth): CoachOnly,
    State(state): State<AppState>,
) -> Result<Json<InviteCodeResponse>, AppError> {
    let invite = coach_invite_codes::get_or_create_invite_code(&state.db, auth.user_id).await?;
    Ok(Json(InviteCodeResponse { code: invite.code }))
}

/// `POST /coach/invite-code/regenerate`: reemplaza el código por uno nuevo.
pub async fn regenerate_invite_code_handler(
    CoachOnly(auth): CoachOnly,
    State(state): State<AppState>,
) -> Result<Json<InviteCodeResponse>, AppError> {
    let invite = coach_invite_codes::regenerate_invite_code(&state.db, auth.user_id).await?;
    Ok(Json(InviteCodeResponse { code: invite.code }))
}

pub fn router() -> Router<AppState> {
    Router::new()
        .route("/coach/invite-code", get(get_invite_code_handler))
        .route(
            "/coach/invite-code/regenerate",
            post(regenerate_invite_code_handler),
        )
}
