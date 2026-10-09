use axum::{Json, Router, extract::State, routing::get};
use serde::Serialize;

use crate::auth::middleware::UserOnly;
use crate::error::AppError;
use crate::models::goal::{GoalSource, NutritionalGoal};
use crate::services::goals;
use crate::state::AppState;

#[derive(Debug, Serialize)]
pub struct GoalResponse {
    pub id: String,
    pub user_id: String,
    pub calories: i32,
    pub protein_g: i32,
    pub fat_g: i32,
    pub source: GoalSource,
    pub set_by: Option<String>,
    pub effective_from: String,
    pub created_at: String,
}

impl From<NutritionalGoal> for GoalResponse {
    fn from(goal: NutritionalGoal) -> Self {
        Self {
            id: goal.id.to_hex(),
            user_id: goal.user_id.to_hex(),
            calories: goal.calories,
            protein_g: goal.protein_g,
            fat_g: goal.fat_g,
            source: goal.source,
            set_by: goal.set_by.map(|id| id.to_hex()),
            effective_from: goal
                .effective_from
                .try_to_rfc3339_string()
                .unwrap_or_default(),
            created_at: goal.created_at.try_to_rfc3339_string().unwrap_or_default(),
        }
    }
}

/// GET /users/me/goals/current — meta vigente del usuario autenticado.
async fn get_current_goal_handler(
    State(state): State<AppState>,
    UserOnly(auth): UserOnly,
) -> Result<Json<GoalResponse>, AppError> {
    let goal = goals::get_current_goal(&state.db, auth.user_id).await?;
    Ok(Json(goal.into()))
}

/// GET /users/me/goals — historial, de la más reciente a la más antigua.
async fn get_goals_history_handler(
    State(state): State<AppState>,
    UserOnly(auth): UserOnly,
) -> Result<Json<Vec<GoalResponse>>, AppError> {
    let history = goals::get_goals_history(&state.db, auth.user_id).await?;
    Ok(Json(history.into_iter().map(GoalResponse::from).collect()))
}

pub fn router() -> Router<AppState> {
    Router::new()
        .route("/users/me/goals/current", get(get_current_goal_handler))
        .route("/users/me/goals", get(get_goals_history_handler))
}
