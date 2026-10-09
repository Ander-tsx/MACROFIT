use axum::{
    Json,
    extract::State,
    http::StatusCode,
    routing::{get, post, put},
    Router,
};
use serde::{Deserialize, Serialize};

use crate::auth::middleware::UserOnly;
use crate::error::{ApiJson, AppError};
use crate::models::profile::UserProfile;
use crate::services::profile::{self, ProfileInput};
use crate::state::AppState;

#[derive(Debug, Deserialize)]
pub struct ProfileRequest {
    pub weight_kg: Option<f64>,
    pub height_cm: Option<f64>,
    pub birth_date: Option<String>,
    pub gender: Option<String>,
    pub training_days: Option<i32>,
    pub objective: Option<String>,
}

impl From<ProfileRequest> for ProfileInput {
    fn from(req: ProfileRequest) -> Self {
        ProfileInput {
            weight_kg: req.weight_kg,
            height_cm: req.height_cm,
            birth_date: req.birth_date,
            gender: req.gender,
            training_days: req.training_days,
            objective: req.objective,
        }
    }
}

#[derive(Debug, Serialize)]
pub struct ProfileResponse {
    pub id: String,
    pub user_id: String,
    pub weight_kg: f64,
    pub height_cm: f64,
    pub birth_date: String,
    pub gender: String,
    pub training_days: i32,
    pub objective: String,
}

impl From<UserProfile> for ProfileResponse {
    fn from(p: UserProfile) -> Self {
        ProfileResponse {
            id: p.id.to_hex(),
            user_id: p.user_id.to_hex(),
            weight_kg: p.weight_kg,
            height_cm: p.height_cm,
            birth_date: p.birth_date.to_string(),
            gender: serde_json::to_value(p.gender)
                .ok()
                .and_then(|v| v.as_str().map(String::from))
                .unwrap_or_default(),
            training_days: p.training_days,
            objective: serde_json::to_value(p.objective)
                .ok()
                .and_then(|v| v.as_str().map(String::from))
                .unwrap_or_default(),
        }
    }
}

/// HU-03 — GET /api/v1/users/me/profile
async fn get_profile_handler(
    UserOnly(auth): UserOnly,
    State(state): State<AppState>,
) -> Result<Json<ProfileResponse>, AppError> {
    let profile = profile::get_profile(&state.db, auth.user_id).await?;
    Ok(Json(ProfileResponse::from(profile)))
}

/// HU-03 / HU-04 — POST /api/v1/users/me/profile
async fn create_profile_handler(
    UserOnly(auth): UserOnly,
    State(state): State<AppState>,
    ApiJson(req): ApiJson<ProfileRequest>,
) -> Result<(StatusCode, Json<ProfileResponse>), AppError> {
    let profile = profile::save_or_update_profile(&state.db, auth.user_id, req.into()).await?;
    Ok((StatusCode::CREATED, Json(ProfileResponse::from(profile))))
}

/// HU-03 / HU-04 — PUT /api/v1/users/me/profile
async fn update_profile_handler(
    UserOnly(auth): UserOnly,
    State(state): State<AppState>,
    ApiJson(req): ApiJson<ProfileRequest>,
) -> Result<Json<ProfileResponse>, AppError> {
    let profile = profile::save_or_update_profile(&state.db, auth.user_id, req.into()).await?;
    Ok(Json(ProfileResponse::from(profile)))
}

pub fn router() -> Router<AppState> {
    Router::new()
        .route("/users/me/profile", get(get_profile_handler))
        .route("/users/me/profile", post(create_profile_handler))
        .route("/users/me/profile", put(update_profile_handler))
}
