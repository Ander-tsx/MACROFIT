use axum::{Json, Router, extract::State, http::StatusCode, routing::get};
use serde::{Deserialize, Serialize};
use utoipa::ToSchema;

use crate::auth::middleware::UserOnly;
use crate::error::{ApiJson, AppError, ErrorResponse};
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

/// Cuerpo de `POST /users/me/profile`. Todo opcional para señalar campo por campo lo que
/// falta; los enumerados llegan como texto y se validan en el servicio. Rangos de TEC-12
/// (`services::profile`).
#[derive(Debug, Deserialize, ToSchema)]
#[schema(description = "Perfil inicial. Todos los campos son obligatorios; rangos de TEC-12.")]
pub struct ProfileRequest {
    #[schema(value_type = Objective, required = true)]
    pub objective: Option<String>,
    #[schema(value_type = Level, required = true)]
    pub level: Option<String>,
    /// Entero de 1 a 7 (un número con decimales se señala en el campo).
    #[schema(value_type = i32, required = true, example = 4)]
    pub training_days: Option<f64>,
    /// De 35 a 250 kg.
    #[schema(value_type = f64, required = true, example = 72.5)]
    pub weight_kg: Option<f64>,
    /// De 130 a 230 cm.
    #[schema(value_type = f64, required = true, example = 170)]
    pub height_cm: Option<f64>,
    #[schema(value_type = Gender, required = true)]
    pub gender: Option<String>,
    /// `YYYY-MM-DD`; edad de 18 a 80 años cumplidos a la fecha UTC actual; no futura.
    #[schema(value_type = String, format = Date, required = true, example = "1996-05-20")]
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

/// Cuerpo de `PATCH /users/me/profile`: los mismos campos que el `POST`, todos opcionales
/// (los ausentes o `null` no cambian) y al menos uno. Mismas reglas.
#[derive(Debug, Deserialize, ToSchema)]
pub struct ProfileUpdateRequest {
    #[schema(value_type = Option<Objective>)]
    pub objective: Option<String>,
    #[schema(value_type = Option<Level>)]
    pub level: Option<String>,
    /// Entero de 1 a 7.
    #[schema(value_type = Option<i32>)]
    pub training_days: Option<f64>,
    /// De 35 a 250 kg.
    pub weight_kg: Option<f64>,
    /// De 130 a 230 cm.
    pub height_cm: Option<f64>,
    #[schema(value_type = Option<Gender>)]
    pub gender: Option<String>,
    /// `YYYY-MM-DD`; edad de 18 a 80 años.
    #[schema(format = Date)]
    pub birth_date: Option<String>,
}

impl From<ProfileUpdateRequest> for ProfileInput {
    fn from(body: ProfileUpdateRequest) -> Self {
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
#[derive(Debug, Serialize, ToSchema)]
pub struct ProfileResponse {
    pub id: String,
    pub user_id: String,
    pub objective: Objective,
    pub level: Level,
    #[schema(example = 4)]
    pub training_days: i32,
    #[schema(example = 72.5)]
    pub weight_kg: f64,
    #[schema(example = 170.0)]
    pub height_cm: f64,
    pub gender: Gender,
    /// `YYYY-MM-DD`.
    #[schema(format = Date, example = "1996-05-20")]
    pub birth_date: String,
    #[schema(format = DateTime)]
    pub created_at: String,
    #[schema(format = DateTime)]
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
#[utoipa::path(
    post,
    path = "/users/me/profile",
    tag = "Perfil",
    summary = "Crea el perfil inicial",
    description = "Todos los campos son obligatorios. Marca `profile_completed` en la cuenta y genera la meta inicial (HU-04).",
    security(("bearer_auth" = ["user"])),
    request_body = ProfileRequest,
    responses(
        (status = 201, description = "Perfil creado", body = ProfileResponse),
        (status = 400, description = "`VALIDATION_ERROR` (cada campo inválido en `fields`) o `INVALID_BODY`", body = ErrorResponse),
        (status = 401, description = "`UNAUTHORIZED` o `TOKEN_REVOKED`", body = ErrorResponse),
        (status = 403, description = "`FORBIDDEN_ROLE` (cuenta `coach`)", body = ErrorResponse),
        (status = 409, description = "`PROFILE_ALREADY_EXISTS` (se edita con `PATCH`)", body = ErrorResponse),
    )
)]
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
#[utoipa::path(
    get,
    path = "/users/me/profile",
    tag = "Perfil",
    summary = "Perfil del usuario de la sesión",
    security(("bearer_auth" = ["user"])),
    responses(
        (status = 200, description = "Perfil", body = ProfileResponse),
        (status = 401, description = "`UNAUTHORIZED` o `TOKEN_REVOKED`", body = ErrorResponse),
        (status = 403, description = "`FORBIDDEN_ROLE` (cuenta `coach`)", body = ErrorResponse),
        (status = 404, description = "`PROFILE_NOT_FOUND` (aún no lo captura)", body = ErrorResponse),
    )
)]
pub async fn get_profile_handler(
    State(state): State<AppState>,
    UserOnly(auth_user): UserOnly,
) -> Result<Json<ProfileResponse>, AppError> {
    let profile = profile_service::get_profile(&state.db, auth_user.user_id).await?;
    Ok(Json(profile.into()))
}

/// HU-03 — `PATCH /api/v1/users/me/profile`. Cambia solo los campos enviados.
#[utoipa::path(
    patch,
    path = "/users/me/profile",
    tag = "Perfil",
    summary = "Edita el perfil",
    description = "Cambia solo los campos enviados. Recalcula la meta si cambian `weight_kg`, `objective` o `training_days`, salvo que la meta vigente la haya fijado un coach.",
    security(("bearer_auth" = ["user"])),
    request_body = ProfileUpdateRequest,
    responses(
        (status = 200, description = "Perfil actualizado", body = ProfileResponse),
        (status = 400, description = "`VALIDATION_ERROR` o `INVALID_BODY` (también sin ningún campo)", body = ErrorResponse),
        (status = 401, description = "`UNAUTHORIZED` o `TOKEN_REVOKED`", body = ErrorResponse),
        (status = 403, description = "`FORBIDDEN_ROLE` (cuenta `coach`)", body = ErrorResponse),
        (status = 404, description = "`PROFILE_NOT_FOUND`", body = ErrorResponse),
    )
)]
pub async fn update_profile_handler(
    State(state): State<AppState>,
    UserOnly(auth_user): UserOnly,
    ApiJson(body): ApiJson<ProfileUpdateRequest>,
) -> Result<Json<ProfileResponse>, AppError> {
    let profile =
        profile_service::update_profile(&state.db, auth_user.user_id, body.into()).await?;
    Ok(Json(profile.into()))
}
