//! HU-12 — rutas del código de invitación del coach (solo rol coach).

use axum::{
    Json, Router,
    extract::State,
    routing::{get, post},
};
use serde::{Deserialize, Serialize};
use utoipa::ToSchema;

use crate::auth::middleware::CoachOnly;
use crate::error::{AppError, ErrorResponse};
use crate::services::coach_invite_codes;
use crate::state::AppState;

#[derive(Debug, Serialize, Deserialize, ToSchema)]
pub struct InviteCodeResponse {
    /// Código que el cliente captura para vincularse (HU-13).
    pub code: String,
}

/// `GET /coach/invite-code`: devuelve el código del coach; lo crea si no existe.
#[utoipa::path(
    get,
    path = "/coach/invite-code",
    tag = "Coach",
    summary = "Código de invitación del coach",
    description = "Devuelve el mismo código en llamadas repetidas; lo crea en la primera.",
    security(("bearer_auth" = ["coach"])),
    responses(
        (status = 200, description = "Código vigente", body = InviteCodeResponse),
        (status = 401, description = "`UNAUTHORIZED` o `TOKEN_REVOKED`", body = ErrorResponse),
        (status = 403, description = "`FORBIDDEN_ROLE` (cuenta `user`)", body = ErrorResponse),
    )
)]
pub async fn get_invite_code_handler(
    CoachOnly(auth): CoachOnly,
    State(state): State<AppState>,
) -> Result<Json<InviteCodeResponse>, AppError> {
    let invite = coach_invite_codes::get_or_create_invite_code(&state.db, auth.user_id).await?;
    Ok(Json(InviteCodeResponse { code: invite.code }))
}

/// `POST /coach/invite-code/regenerate`: reemplaza el código por uno nuevo.
#[utoipa::path(
    post,
    path = "/coach/invite-code/regenerate",
    tag = "Coach",
    summary = "Regenera el código de invitación",
    description = "Crea un código nuevo e invalida el anterior.",
    security(("bearer_auth" = ["coach"])),
    responses(
        (status = 200, description = "Código nuevo", body = InviteCodeResponse),
        (status = 401, description = "`UNAUTHORIZED` o `TOKEN_REVOKED`", body = ErrorResponse),
        (status = 403, description = "`FORBIDDEN_ROLE` (cuenta `user`)", body = ErrorResponse),
    )
)]
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
