use axum::{
    Json, Router,
    extract::{Path, State},
    http::StatusCode,
    routing::get,
};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use utoipa::ToSchema;

use crate::auth::middleware::{CoachOnly, UserOnly};
use crate::error::{ApiJson, AppError, ErrorResponse};
use crate::models::goal::{GoalSource, NutritionalGoal};
use crate::models::user::User;
use crate::services::coach_links;
use crate::services::goals::{self, CoachGoalInput};
use crate::state::AppState;

#[derive(Debug, Serialize, ToSchema)]
pub struct GoalResponse {
    pub id: String,
    pub user_id: String,
    #[schema(example = 2200)]
    pub calories: i32,
    #[schema(example = 160)]
    pub protein_g: i32,
    #[schema(example = 70)]
    pub fat_g: i32,
    /// `system` (calculada) o `coach`.
    pub source: GoalSource,
    /// Id del coach si `source` es `coach`.
    pub set_by: Option<String>,
    #[schema(format = DateTime)]
    pub effective_from: String,
    #[schema(format = DateTime)]
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

/// HU-04 — `GET /api/v1/users/me/goals/current`. Meta vigente del usuario autenticado.
#[utoipa::path(
    get,
    path = "/users/me/goals/current",
    tag = "Metas",
    summary = "Meta nutricional vigente",
    description = "La de `effective_from` más reciente que ya empezó; una meta de coach vigente tiene prioridad sobre las calculadas. Si no hay ninguna, se genera la inicial desde el perfil.",
    security(("bearer_auth" = ["user"])),
    responses(
        (status = 200, description = "Meta vigente", body = GoalResponse),
        (status = 401, description = "`UNAUTHORIZED` o `TOKEN_REVOKED`", body = ErrorResponse),
        (status = 403, description = "`FORBIDDEN_ROLE` (cuenta `coach`)", body = ErrorResponse),
        (status = 404, description = "`PROFILE_NOT_FOUND` (sin metas ni perfil)", body = ErrorResponse),
    )
)]
pub async fn get_current_goal_handler(
    State(state): State<AppState>,
    UserOnly(auth): UserOnly,
) -> Result<Json<GoalResponse>, AppError> {
    let goal = goals::get_current_goal(&state.db, auth.user_id).await?;
    Ok(Json(goal.into()))
}

/// HU-04 — `GET /api/v1/users/me/goals`. Historial, de la más reciente a la más antigua.
#[utoipa::path(
    get,
    path = "/users/me/goals",
    tag = "Metas",
    summary = "Historial de metas",
    description = "Metas calculadas y del coach, de la más reciente a la más antigua (`effective_from`).",
    security(("bearer_auth" = ["user"])),
    responses(
        (status = 200, description = "Historial", body = [GoalResponse]),
        (status = 401, description = "`UNAUTHORIZED` o `TOKEN_REVOKED`", body = ErrorResponse),
        (status = 403, description = "`FORBIDDEN_ROLE` (cuenta `coach`)", body = ErrorResponse),
        (status = 404, description = "`PROFILE_NOT_FOUND` (sin metas ni perfil)", body = ErrorResponse),
    )
)]
pub async fn get_goals_history_handler(
    State(state): State<AppState>,
    UserOnly(auth): UserOnly,
) -> Result<Json<Vec<GoalResponse>>, AppError> {
    let history = goals::get_goals_history(&state.db, auth.user_id).await?;
    Ok(Json(history.into_iter().map(GoalResponse::from).collect()))
}

/// Cuerpo de `POST /coach/clients/{clientId}/goals`. Todo opcional para señalar campo por campo.
#[derive(Debug, Deserialize, ToSchema)]
#[schema(description = "Meta que fija el coach. Todos los campos son obligatorios.")]
pub struct CoachGoalRequest {
    /// Entero de 1 a 10 000.
    #[schema(value_type = i32, required = true, example = 2200)]
    pub calories: Option<Value>,
    /// Entero de 1 a 1 000.
    #[schema(value_type = i32, required = true, example = 160)]
    pub protein_g: Option<Value>,
    /// Entero de 1 a 1 000.
    #[schema(value_type = i32, required = true, example = 70)]
    pub fat_g: Option<Value>,
    /// `YYYY-MM-DD` (medianoche UTC).
    #[schema(value_type = String, format = Date, required = true, example = "2026-10-09")]
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

#[derive(Debug, Serialize, ToSchema)]
pub struct ClientResponse {
    pub id: String,
    #[schema(example = "Ana")]
    pub name: String,
    #[schema(example = "ana@macrofit.com")]
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
#[utoipa::path(
    get,
    path = "/coach/clients",
    tag = "Coach",
    summary = "Clientes vinculados",
    description = "Clientes con vinculación activa, ordenados por nombre.",
    security(("bearer_auth" = ["coach"])),
    responses(
        (status = 200, description = "Clientes", body = [ClientResponse]),
        (status = 401, description = "`UNAUTHORIZED` o `TOKEN_REVOKED`", body = ErrorResponse),
        (status = 403, description = "`FORBIDDEN_ROLE` (cuenta `user`)", body = ErrorResponse),
    )
)]
pub async fn list_clients_handler(
    State(state): State<AppState>,
    CoachOnly(coach): CoachOnly,
) -> Result<Json<Vec<ClientResponse>>, AppError> {
    let clients = coach_links::list_clients(&state.db, coach.user_id).await?;
    Ok(Json(
        clients.into_iter().map(ClientResponse::from).collect(),
    ))
}

/// HU-05 — `POST /api/v1/coach/clients/{clientId}/goals`. El coach fija una meta para su cliente.
#[utoipa::path(
    post,
    path = "/coach/clients/{clientId}/goals",
    tag = "Coach",
    summary = "Fija una meta para un cliente",
    description = "La meta se agrega al historial (`source: coach`); las anteriores no se modifican. La vinculación se comprueba antes de validar el cuerpo.",
    security(("bearer_auth" = ["coach"])),
    params(("clientId" = String, Path, description = "Id del cliente vinculado")),
    request_body = CoachGoalRequest,
    responses(
        (status = 201, description = "Meta creada", body = GoalResponse),
        (status = 400, description = "`VALIDATION_ERROR` (un texto o un decimal se señalan en su campo) o `INVALID_BODY`", body = ErrorResponse),
        (status = 401, description = "`UNAUTHORIZED` o `TOKEN_REVOKED`", body = ErrorResponse),
        (status = 403, description = "`FORBIDDEN_ROLE` (cuenta `user`) o `CLIENT_NOT_LINKED` (sin vinculación activa, id inexistente o mal formado)", body = ErrorResponse),
    )
)]
pub async fn set_client_goal_handler(
    State(state): State<AppState>,
    CoachOnly(coach): CoachOnly,
    Path(client_id): Path<String>,
    ApiJson(body): ApiJson<CoachGoalRequest>,
) -> Result<(StatusCode, Json<GoalResponse>), AppError> {
    let goal = goals::set_client_goal(&state.db, coach.user_id, &client_id, body.into()).await?;
    Ok((StatusCode::CREATED, Json(goal.into())))
}

/// HU-05 — `GET /api/v1/coach/clients/{clientId}/goals`. Historial de metas del cliente.
#[utoipa::path(
    get,
    path = "/coach/clients/{clientId}/goals",
    tag = "Coach",
    summary = "Historial de metas de un cliente",
    description = "Metas del coach y calculadas, de la más reciente a la más antigua.",
    security(("bearer_auth" = ["coach"])),
    params(("clientId" = String, Path, description = "Id del cliente vinculado")),
    responses(
        (status = 200, description = "Historial", body = [GoalResponse]),
        (status = 401, description = "`UNAUTHORIZED` o `TOKEN_REVOKED`", body = ErrorResponse),
        (status = 403, description = "`FORBIDDEN_ROLE` (cuenta `user`) o `CLIENT_NOT_LINKED`", body = ErrorResponse),
    )
)]
pub async fn get_client_goals_handler(
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
