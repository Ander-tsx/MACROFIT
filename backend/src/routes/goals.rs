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
use crate::services::coach_links::{self, ClientSummary};
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

/// Resumen de la meta vigente de un cliente en la lista del coach (HU-24).
#[derive(Debug, Serialize, ToSchema)]
#[schema(
    description = "Meta vigente del cliente: la del coach tiene prioridad sobre la calculada."
)]
pub struct ClientGoalSummary {
    #[schema(example = 2200)]
    pub calories: i32,
    #[schema(example = 160)]
    pub protein_g: i32,
    #[schema(example = 70)]
    pub fat_g: i32,
    /// `system` (calculada) o `coach`.
    pub source: GoalSource,
}

impl From<NutritionalGoal> for ClientGoalSummary {
    fn from(goal: NutritionalGoal) -> Self {
        Self {
            calories: goal.calories,
            protein_g: goal.protein_g,
            fat_g: goal.fat_g,
            source: goal.source,
        }
    }
}

#[derive(Debug, Serialize, ToSchema)]
#[schema(
    description = "Cliente con vinculación activa (HU-05), con su meta vigente y su último registro de comida (HU-24)."
)]
pub struct ClientResponse {
    pub id: String,
    #[schema(example = "Ana")]
    pub name: String,
    #[schema(example = "ana@macrofit.com")]
    pub email: String,
    /// Meta vigente; null si el cliente aún no tiene metas (sin perfil ni meta del coach).
    #[schema(required = true)]
    pub goal: Option<ClientGoalSummary>,
    /// Fecha y hora del registro de comida más reciente (RFC 3339, UTC); null si no tiene registros.
    #[schema(required = true, format = DateTime, example = "2026-10-17T01:30:00Z")]
    pub last_meal_at: Option<String>,
}

impl From<ClientSummary> for ClientResponse {
    fn from(client: ClientSummary) -> Self {
        Self {
            id: client.user.id_hex(),
            name: client.user.name,
            email: client.user.email,
            goal: client.goal.map(ClientGoalSummary::from),
            last_meal_at: client
                .last_meal_at
                .and_then(|at| at.try_to_rfc3339_string().ok()),
        }
    }
}

/// HU-05 y HU-24 — `GET /api/v1/coach/clients`. Clientes con vinculación activa del coach, con su meta
/// vigente y la fecha de su último registro de comida.
#[utoipa::path(
    get,
    path = "/coach/clients",
    tag = "Coach",
    summary = "Clientes vinculados",
    description = "Clientes con vinculación activa, ordenados por nombre, con su meta vigente (`goal`, misma regla que `GET /users/me/goals/current`) y la fecha y hora de su último registro de comida (`last_meal_at`). Ambos son null si no hay datos.",
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

#[cfg(test)]
mod tests {
    use mongodb::bson::{DateTime, oid::ObjectId};
    use serde_json::json;

    use super::*;
    use crate::models::user::{Role, User};

    fn ana() -> User {
        User {
            id: Some(ObjectId::parse_str("6ad0a1b2c3d4e5f6a7b8c9d0").unwrap()),
            name: "Ana".into(),
            email: "ana@macrofit.test".into(),
            password_hash: "hash".into(),
            role: Role::User,
            privacy_accepted_at: None,
            privacy_version: None,
            profile_completed: true,
            created_at: DateTime::now(),
        }
    }

    #[test]
    fn cliente_con_meta_y_registro_se_serializa_con_el_contrato() {
        let user = ana();
        let goal = NutritionalGoal {
            id: ObjectId::new(),
            user_id: user.id.unwrap(),
            calories: 2200,
            protein_g: 160,
            fat_g: 70,
            source: GoalSource::Coach,
            set_by: Some(ObjectId::new()),
            effective_from: DateTime::now(),
            created_at: DateTime::now(),
        };
        let client = ClientSummary {
            user,
            goal: Some(goal),
            last_meal_at: Some(DateTime::parse_rfc3339_str("2026-10-17T01:30:00Z").unwrap()),
        };

        let body = serde_json::to_value(ClientResponse::from(client)).unwrap();
        assert_eq!(
            body,
            json!({
                "id": "6ad0a1b2c3d4e5f6a7b8c9d0",
                "name": "Ana",
                "email": "ana@macrofit.test",
                "goal": { "calories": 2200, "protein_g": 160, "fat_g": 70, "source": "coach" },
                "last_meal_at": "2026-10-17T01:30:00Z"
            })
        );
    }

    #[test]
    fn cliente_sin_meta_ni_registros_conserva_los_campos_en_null() {
        let client = ClientSummary {
            user: ana(),
            goal: None,
            last_meal_at: None,
        };

        let body = serde_json::to_value(ClientResponse::from(client)).unwrap();
        assert_eq!(
            body,
            json!({
                "id": "6ad0a1b2c3d4e5f6a7b8c9d0",
                "name": "Ana",
                "email": "ana@macrofit.test",
                "goal": null,
                "last_meal_at": null
            })
        );
    }
}
