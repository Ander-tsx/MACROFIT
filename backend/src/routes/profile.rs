use axum::{Json, Router, extract::State, http::StatusCode, routing::get};
use serde::{Deserialize, Serialize};

use crate::auth::middleware::UserOnly;
use crate::error::{ApiJson, AppError};
use crate::models::profile::{Gender, Level, Objective, UserProfile};
use crate::services::profile::{self as profile_service, ProfileInput};
use crate::state::AppState;
use crate::validation::date_to_string;

pub fn router() -> Router<AppState> {
    Router::new().route(
        "/users/me/profile",
        get(get_profile_handler)
            .post(create_profile_handler)
            .patch(update_profile_handler),
    )
}

// ---------- DTOs ----------

/// Cuerpo de `POST` y `PATCH /users/me/profile`. Todo opcional para señalar campo por
/// campo lo que falta; los enumerados llegan como texto y se validan en el servicio.
#[derive(Debug, Deserialize)]
pub struct ProfileRequest {
    pub objective: Option<String>,
    pub level: Option<String>,
    pub training_days: Option<f64>,
    pub weight_kg: Option<f64>,
    pub height_cm: Option<f64>,
    pub gender: Option<String>,
    /// `YYYY-MM-DD`.
    pub birth_date: Option<String>,
}

impl From<ProfileRequest> for ProfileInput {
    fn from(body: ProfileRequest) -> Self {
        Self {
            objective: body.objective,
            level: body.level,
            training_days: body.training_days,
            weight_kg: body.weight_kg,
            height_cm: body.height_cm,
            gender: body.gender,
            birth_date: body.birth_date,
        }
    }
}

/// Representación pública del perfil.
#[derive(Debug, Serialize)]
pub struct ProfileResponse {
    pub id: String,
    pub user_id: String,
    pub objective: Objective,
    pub level: Level,
    pub training_days: i32,
    pub weight_kg: f64,
    pub height_cm: f64,
    pub gender: Gender,
    /// `YYYY-MM-DD`.
    pub birth_date: String,
    pub created_at: String,
    pub updated_at: String,
}

impl From<UserProfile> for ProfileResponse {
    fn from(profile: UserProfile) -> Self {
        Self {
            id: profile.id.to_hex(),
            user_id: profile.user_id.to_hex(),
            objective: profile.objective,
            level: profile.level,
            training_days: profile.training_days,
            weight_kg: profile.weight_kg,
            height_cm: profile.height_cm,
            gender: profile.gender,
            birth_date: date_to_string(profile.birth_date),
            created_at: profile
                .created_at
                .try_to_rfc3339_string()
                .unwrap_or_default(),
            updated_at: profile
                .updated_at
                .try_to_rfc3339_string()
                .unwrap_or_default(),
        }
    }
}

// ---------- Handlers ----------

/// HU-03 — `POST /api/v1/users/me/profile`. Crea el perfil y marca `profile_completed`.
pub async fn create_profile_handler(
    State(state): State<AppState>,
    UserOnly(auth_user): UserOnly,
    ApiJson(body): ApiJson<ProfileRequest>,
) -> Result<(StatusCode, Json<ProfileResponse>), AppError> {
    let profile =
        profile_service::create_profile(&state.db, auth_user.user_id, body.into()).await?;
    Ok((StatusCode::CREATED, Json(profile.into())))
}

/// HU-03 — `GET /api/v1/users/me/profile`.
pub async fn get_profile_handler(
    State(state): State<AppState>,
    UserOnly(auth_user): UserOnly,
) -> Result<Json<ProfileResponse>, AppError> {
    let profile = profile_service::get_profile(&state.db, auth_user.user_id).await?;
    Ok(Json(profile.into()))
}

/// HU-03 — `PATCH /api/v1/users/me/profile`. Cambia solo los campos enviados.
pub async fn update_profile_handler(
    State(state): State<AppState>,
    UserOnly(auth_user): UserOnly,
    ApiJson(body): ApiJson<ProfileRequest>,
) -> Result<Json<ProfileResponse>, AppError> {
    let profile =
        profile_service::update_profile(&state.db, auth_user.user_id, body.into()).await?;
    Ok(Json(profile.into()))
}
