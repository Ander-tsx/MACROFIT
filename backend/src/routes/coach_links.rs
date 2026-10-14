//! HU-13 / HU-14 — rutas de vinculación y desvinculación con el coach.

use axum::{Json, Router, extract::State, http::StatusCode, routing::post};
use serde::{Deserialize, Serialize};

use crate::auth::middleware::UserOnly;
use crate::error::{ApiJson, AppError, ErrorResponse};
use crate::services::coach_links::{self, LinkCoachInput};
use crate::state::AppState;

#[derive(Debug, Deserialize, utoipa::ToSchema)]
#[schema(description = "Datos para vincularse con un coach mediante código de invitación.")]
pub struct LinkCoachRequest {
    /// Código de invitación del coach (6 caracteres alfanuméricos).
    #[schema(value_type = String, required = true, example = "AB3K9Z")]
    pub invite_code: Option<String>,
}

#[derive(Debug, Serialize, utoipa::ToSchema)]
#[schema(description = "Respuesta de vinculación activa con el coach.")]
pub struct CoachLinkResponse {
    #[schema(value_type = String, example = "6ac6...")]
    pub id: String,
    #[schema(value_type = String, example = "6ac5...")]
    pub coach_id: String,
    #[schema(value_type = String, example = "Laura")]
    pub coach_name: String,
    #[schema(value_type = String, example = "laura@macrofit.com")]
    pub coach_email: String,
    #[schema(value_type = String, example = "active")]
    pub status: String,
}

/// HU-13 — POST /api/v1/users/me/coach-link
#[utoipa::path(
    post,
    path = "/users/me/coach-link",
    tag = "Vinculaciones",
    summary = "Vincularse con un coach mediante su código de invitación (HU-13)",
    description = "El usuario autenticado se vincula con el coach dueño del código. Si ya existía una vinculación previa con ese coach, se reactiva. Un usuario solo puede tener una vinculación activa a la vez.",
    security(("bearer_auth" = ["user"])),
    request_body = LinkCoachRequest,
    responses(
        (status = 201, description = "Vinculación activa creada o reactivada", body = CoachLinkResponse),
        (status = 400, description = "`VALIDATION_ERROR` o `INVALID_BODY`", body = ErrorResponse),
        (status = 401, description = "`UNAUTHORIZED` o `TOKEN_REVOKED`", body = ErrorResponse),
        (status = 403, description = "`FORBIDDEN_ROLE` (cuenta `coach`)", body = ErrorResponse),
        (status = 404, description = "`INVITE_CODE_NOT_FOUND`", body = ErrorResponse),
        (status = 409, description = "`USER_ALREADY_LINKED`", body = ErrorResponse),
    )
)]
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

/// HU-14 — DELETE /api/v1/users/me/coach-link
#[utoipa::path(
    delete,
    path = "/users/me/coach-link",
    tag = "Vinculaciones",
    summary = "Desvincularse del coach (HU-14)",
    description = "El usuario autenticado se desvincula de su coach activo para dejar de compartir sus datos.",
    security(("bearer_auth" = ["user"])),
    responses(
        (status = 204, description = "Desvinculación exitosa"),
        (status = 401, description = "`UNAUTHORIZED` o `TOKEN_REVOKED`", body = ErrorResponse),
        (status = 403, description = "`FORBIDDEN_ROLE` (cuenta `coach`)", body = ErrorResponse),
        (status = 404, description = "`USER_NOT_LINKED`", body = ErrorResponse),
    )
)]
pub async fn unlink_coach_handler(
    UserOnly(auth): UserOnly,
    State(state): State<AppState>,
) -> Result<StatusCode, AppError> {
    coach_links::unlink_coach(&state.db, auth.user_id).await?;
    Ok(StatusCode::NO_CONTENT)
}

pub fn router() -> Router<AppState> {
    Router::new().route(
        "/users/me/coach-link",
        post(link_coach_handler).delete(unlink_coach_handler),
    )
}
