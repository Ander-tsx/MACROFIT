//! Datos de prueba. Solo se monta con `APP_ENV=development` (ver `routes::api_router`).

use axum::{Json, Router, extract::State, http::StatusCode, routing::post};
use serde::{Deserialize, Serialize};
use utoipa::ToSchema;

use crate::error::{ApiJson, AppError, ErrorResponse};
use crate::models::coach_link::{CoachLink, LinkStatus};
use crate::services::coach_links::{self, SeedLinkInput};
use crate::state::AppState;

pub fn router() -> Router<AppState> {
    Router::new()
        .route("/dev/seed/coach-links", post(seed_coach_link_handler))
        .route(
            "/dev/seed/exercises",
            post(crate::routes::exercises::seed_exercises_handler),
        )
}

#[derive(Debug, Deserialize, ToSchema)]
pub struct SeedCoachLinkRequest {
    /// Id de una cuenta existente con rol `coach`.
    #[schema(value_type = String, required = true)]
    pub coach_id: Option<String>,
    /// Id de una cuenta existente con rol `user`.
    #[schema(value_type = String, required = true)]
    pub user_id: Option<String>,
}

#[derive(Debug, Serialize, ToSchema)]
pub struct CoachLinkResponse {
    pub id: String,
    pub coach_id: String,
    pub user_id: String,
    pub status: LinkStatus,
    #[schema(format = DateTime)]
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
#[utoipa::path(
    post,
    path = "/dev/seed/coach-links",
    tag = "Desarrollo",
    summary = "Vincula un coach con un usuario de prueba",
    description = "Solo existe con `APP_ENV=development`; en otro ambiente la ruta no se monta (404). Sin autenticación. Crea la vinculación o la reactiva.",
    request_body = SeedCoachLinkRequest,
    responses(
        (status = 201, description = "Vinculación activa", body = CoachLinkResponse),
        (status = 400, description = "`VALIDATION_ERROR` (ids inválidos o de cuentas con otro rol) o `INVALID_BODY`", body = ErrorResponse),
    )
)]
pub async fn seed_coach_link_handler(
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
