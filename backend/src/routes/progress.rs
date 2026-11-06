//! HU-22 / HU-23 — rutas del progreso del usuario y de clientes para el coach.

use axum::{
    Json, Router,
    extract::{Path, Query, State},
    routing::get,
};
use serde::Deserialize;

use crate::auth::middleware::{CoachOnly, UserOnly};
use crate::error::{AppError, ErrorResponse};
use crate::services::{
    coach_links,
    progress::{self, ProgressResponse},
};
use crate::state::AppState;

#[derive(Debug, Deserialize, utoipa::ToSchema)]
pub struct ProgressQuery {
    /// Fecha de inicio (YYYY-MM-DD).
    #[schema(value_type = String, example = "2026-10-01")]
    pub from: Option<String>,
    /// Fecha de fin (YYYY-MM-DD).
    #[schema(value_type = String, example = "2026-10-31")]
    pub to: Option<String>,
}

/// HU-22 — GET /api/v1/users/me/progress
#[utoipa::path(
    get,
    path = "/users/me/progress",
    tag = "Progreso",
    summary = "Series de progreso del usuario (HU-22)",
    description = "Devuelve las series de peso, macros por día frente a metas y cumplimiento semanal.",
    security(("bearer_auth" = ["user"])),
    params(
        ("from" = Option<String>, Query, description = "Fecha de inicio (YYYY-MM-DD)"),
        ("to" = Option<String>, Query, description = "Fecha de fin (YYYY-MM-DD)")
    ),
    responses(
        (status = 200, description = "Progreso del usuario", body = ProgressResponse),
        (status = 400, description = "`VALIDATION_ERROR` (fechas inválidas, rango > 93 días o from > to)", body = ErrorResponse),
        (status = 401, description = "`UNAUTHORIZED` o `TOKEN_REVOKED`", body = ErrorResponse),
        (status = 403, description = "`FORBIDDEN_ROLE` (cuenta `coach`)", body = ErrorResponse),
    )
)]
pub async fn get_my_progress_handler(
    UserOnly(auth): UserOnly,
    State(state): State<AppState>,
    Query(query): Query<ProgressQuery>,
) -> Result<Json<ProgressResponse>, AppError> {
    let progress = progress::get_progress(
        &state.db,
        auth.user_id,
        state.utc_offset,
        query.from,
        query.to,
    )
    .await?;
    Ok(Json(progress))
}

/// HU-23 — GET /api/v1/coach/clients/{clientId}/progress
#[utoipa::path(
    get,
    path = "/coach/clients/{clientId}/progress",
    tag = "Coach",
    summary = "Progreso histórico de un cliente (HU-23)",
    description = "Devuelve el progreso histórico del cliente para su coach. Requiere vinculación activa.",
    security(("bearer_auth" = ["coach"])),
    params(
        ("clientId" = String, Path, description = "Id del cliente"),
        ("from" = Option<String>, Query, description = "Fecha de inicio (YYYY-MM-DD)"),
        ("to" = Option<String>, Query, description = "Fecha de fin (YYYY-MM-DD)")
    ),
    responses(
        (status = 200, description = "Progreso del cliente", body = ProgressResponse),
        (status = 400, description = "`VALIDATION_ERROR`", body = ErrorResponse),
        (status = 401, description = "`UNAUTHORIZED`", body = ErrorResponse),
        (status = 403, description = "`FORBIDDEN_ROLE` (cuenta `user`) o `CLIENT_NOT_LINKED`", body = ErrorResponse),
    )
)]
pub async fn get_client_progress_handler(
    CoachOnly(coach): CoachOnly,
    State(state): State<AppState>,
    Path(client_id): Path<String>,
    Query(query): Query<ProgressQuery>,
) -> Result<Json<ProgressResponse>, AppError> {
    let client_id = coach_links::require_active_link(&state.db, coach.user_id, &client_id).await?;

    let progress =
        progress::get_progress(&state.db, client_id, state.utc_offset, query.from, query.to)
            .await?;
    Ok(Json(progress))
}

pub fn router() -> Router<AppState> {
    Router::new()
        .route("/users/me/progress", get(get_my_progress_handler))
        .route(
            "/coach/clients/:clientId/progress",
            get(get_client_progress_handler),
        )
}
