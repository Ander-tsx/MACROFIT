use axum::{
    Json, Router,
    extract::{Query, State, rejection::QueryRejection},
    routing::get,
};
use serde::{Deserialize, Serialize};

use crate::auth::middleware::UserOnly;
use crate::error::{AppError, ErrorResponse};
use crate::models::goal::GoalSource;
use crate::services::summary::{self, DailySummary, DayGoal, Totals};
use crate::state::AppState;

#[derive(Debug, Serialize, utoipa::ToSchema)]
#[schema(description = "Calorías y macros del resumen.")]
pub struct TotalsResponse {
    #[schema(example = 1050.5)]
    pub calories_kcal: f64,
    #[schema(example = 70.0)]
    pub protein_g: f64,
    #[schema(example = 35.5)]
    pub fat_g: f64,
}

impl From<Totals> for TotalsResponse {
    fn from(totals: Totals) -> Self {
        Self {
            calories_kcal: totals.calories_kcal,
            protein_g: totals.protein_g,
            fat_g: totals.fat_g,
        }
    }
}

#[derive(Debug, Serialize, utoipa::ToSchema)]
#[schema(description = "Meta vigente ese día con su origen.")]
pub struct DayGoalResponse {
    /// `system` (calculada) o `coach`.
    pub source: GoalSource,
    #[schema(example = 2200.0)]
    pub calories_kcal: f64,
    #[schema(example = 160.0)]
    pub protein_g: f64,
    #[schema(example = 70.0)]
    pub fat_g: f64,
}

impl From<DayGoal> for DayGoalResponse {
    fn from(goal: DayGoal) -> Self {
        Self {
            source: goal.source,
            calories_kcal: goal.totals.calories_kcal,
            protein_g: goal.totals.protein_g,
            fat_g: goal.totals.fat_g,
        }
    }
}

#[derive(Debug, Serialize, utoipa::ToSchema)]
#[schema(description = "Consumo del día comparado con la meta vigente.")]
pub struct DailySummaryResponse {
    /// Día consultado, `YYYY-MM-DD`.
    #[schema(example = "2026-10-16")]
    pub date: String,
    pub goal: DayGoalResponse,
    /// Suma de los registros de comida del día; en 0 si no hay registros.
    pub consumed: TotalsResponse,
    /// Meta − consumido. Negativo cuando el consumo supera la meta.
    pub remaining: TotalsResponse,
}

impl From<DailySummary> for DailySummaryResponse {
    fn from(summary: DailySummary) -> Self {
        Self {
            date: summary.date,
            goal: summary.goal.into(),
            consumed: summary.consumed.into(),
            remaining: summary.remaining.into(),
        }
    }
}

#[derive(Debug, Deserialize, utoipa::IntoParams)]
#[into_params(parameter_in = Query)]
pub struct DailySummaryQuery {
    /// Día a consultar (YYYY-MM-DD) en hora de México (APP_UTC_OFFSET). Obligatorio.
    #[param(value_type = String, format = Date, required = true, example = "2026-10-16")]
    pub date: Option<String>,
}

/// HU-10 — GET /api/v1/users/me/summary/daily?date=YYYY-MM-DD. Consumo del día contra la meta vigente (RF-09).
#[utoipa::path(
    get,
    path = "/users/me/summary/daily",
    tag = "Resumen",
    summary = "Resumen diario contra la meta (HU-10)",
    description = "Devuelve lo consumido ese día, la meta vigente (con su origen `system` o `coach`) y lo que falta: `remaining` = meta − consumido, negativo si el consumo la supera. Un día sin registros devuelve consumo en 0. Sin meta ni perfil responde igual que `GET /users/me/goals/current`.",
    security(("bearer_auth" = ["user"])),
    params(DailySummaryQuery),
    responses(
        (status = 200, description = "Resumen del día", body = DailySummaryResponse),
        (status = 400, description = "`VALIDATION_ERROR` en `date` (ausente o con formato distinto de `YYYY-MM-DD`)", body = ErrorResponse),
        (status = 401, description = "`UNAUTHORIZED` o `TOKEN_REVOKED`", body = ErrorResponse),
        (status = 403, description = "`FORBIDDEN_ROLE` (cuenta `coach`)", body = ErrorResponse),
        (status = 404, description = "`PROFILE_NOT_FOUND`: el usuario no tiene perfil ni meta", body = ErrorResponse),
    )
)]
pub async fn get_daily_summary_handler(
    State(state): State<AppState>,
    UserOnly(auth): UserOnly,
    query: Result<Query<DailySummaryQuery>, QueryRejection>,
) -> Result<Json<DailySummaryResponse>, AppError> {
    let Query(query) = query.map_err(|rejection| AppError::InvalidBody(rejection.body_text()))?;
    let summary =
        summary::get_daily_summary(&state.db, auth.user_id, state.utc_offset, query.date).await?;
    Ok(Json(summary.into()))
}

pub fn router() -> Router<AppState> {
    Router::new().route("/users/me/summary/daily", get(get_daily_summary_handler))
}
