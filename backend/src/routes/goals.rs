use axum::{
    Json, Router,
    extract::{Path, State},
    http::StatusCode,
    routing::get,
};
use serde::{Deserialize, Serialize};
use serde_json::Value;

use crate::auth::middleware::{CoachOnly, UserOnly};
use crate::error::{ApiJson, AppError};
use crate::models::goal::{GoalSource, NutritionalGoal};
use crate::models::user::User;
use crate::services::coach_links;
use crate::services::goals::{self, CoachGoalInput};
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

/// Cuerpo de `POST /coach/clients/{clientId}/goals`. Todo opcional para señalar campo por campo.
#[derive(Debug, Deserialize)]
pub struct CoachGoalRequest {
    pub calories: Option<Value>,
    pub protein_g: Option<Value>,
    pub fat_g: Option<Value>,
    /// `YYYY-MM-DD`.
    pub effective_from: Option<String>,
}

impl From<CoachGoalRequest> for CoachGoalInput {
    fn from(body: CoachGoalRequest) -> Self {
        Self {
            calories: body.calories,
            protein_g: body.protein_g,
            fat_g: body.fat_g,
            effective_from: body.effective_from,
        }
    }
}

#[derive(Debug, Serialize)]
pub struct ClientResponse {
    pub id: String,
    pub name: String,
    pub email: String,
}

impl From<User> for ClientResponse {
    fn from(user: User) -> Self {
        Self {
            id: user.id_hex(),
            name: user.name,
            email: user.email,
        }
    }
}

/// HU-05 — `GET /api/v1/coach/clients`. Clientes con vinculación activa del coach.
// TODO(HU-24): la lista completa de clientes (con su información) reemplaza a este endpoint mínimo.
async fn list_clients_handler(
    State(state): State<AppState>,
    CoachOnly(coach): CoachOnly,
) -> Result<Json<Vec<ClientResponse>>, AppError> {
    let clients = coach_links::list_clients(&state.db, coach.user_id).await?;
    Ok(Json(
        clients.into_iter().map(ClientResponse::from).collect(),
    ))
}

/// HU-05 — `POST /api/v1/coach/clients/{clientId}/goals`. El coach fija una meta para su cliente.
async fn set_client_goal_handler(
    State(state): State<AppState>,
    CoachOnly(coach): CoachOnly,
    Path(client_id): Path<String>,
    ApiJson(body): ApiJson<CoachGoalRequest>,
) -> Result<(StatusCode, Json<GoalResponse>), AppError> {
    let goal = goals::set_client_goal(&state.db, coach.user_id, &client_id, body.into()).await?;
    Ok((StatusCode::CREATED, Json(goal.into())))
}

/// HU-05 — `GET /api/v1/coach/clients/{clientId}/goals`. Historial de metas del cliente.
async fn get_client_goals_handler(
    State(state): State<AppState>,
    CoachOnly(coach): CoachOnly,
    Path(client_id): Path<String>,
) -> Result<Json<Vec<GoalResponse>>, AppError> {
    let history = goals::get_client_goals(&state.db, coach.user_id, &client_id).await?;
    Ok(Json(history.into_iter().map(GoalResponse::from).collect()))
}

pub fn router() -> Router<AppState> {
    Router::new()
        .route("/users/me/goals/current", get(get_current_goal_handler))
        .route("/users/me/goals", get(get_goals_history_handler))
        .route("/coach/clients", get(list_clients_handler))
        .route(
            "/coach/clients/:client_id/goals",
            get(get_client_goals_handler).post(set_client_goal_handler),
        )
}
