use axum::{
    Json, Router,
    extract::State,
    http::StatusCode,
    routing::{get, post},
};
use serde::{Deserialize, Serialize};

use crate::auth::middleware::{AuthenticatedUser, CoachOnly};
use crate::error::{ApiJson, AppError};
use crate::models::user::{Role, User};
use crate::services::auth::{self as auth_service, RegisterInput};
use crate::services::session::{self, IssuedTokens};
use crate::state::AppState;

pub fn router() -> Router<AppState> {
    Router::new()
        .route("/auth/register", post(register_handler))
        .route("/auth/login", post(login_handler))
        .route("/auth/refresh", post(refresh_handler))
        .route("/auth/logout", post(logout_handler))
        .route("/auth/me", get(me_handler))
        .route("/coach/test", get(coach_only_handler))
}

// ---------- DTOs ----------

/// Cuerpo de `POST /auth/register`. Todos los campos son opcionales para que
/// la validación pueda señalar cuál falta en lugar de rechazar el JSON completo.
#[derive(Debug, Deserialize)]
pub struct RegisterRequest {
    pub name: Option<String>,
    pub email: Option<String>,
    pub password: Option<String>,
    pub role: Option<String>,
    pub privacy_accepted: Option<bool>,
}

#[derive(Debug, Deserialize)]
pub struct LoginRequest {
    pub email: Option<String>,
    pub password: Option<String>,
}

/// Representación pública de una cuenta. Nunca incluye la contraseña ni su hash.
#[derive(Debug, Serialize)]
pub struct UserResponse {
    pub id: String,
    pub name: String,
    pub email: String,
    pub role: Role,
    pub profile_completed: bool,
}

impl From<User> for UserResponse {
    fn from(user: User) -> Self {
        Self {
            id: user.id_hex(),
            name: user.name,
            email: user.email,
            role: user.role,
            profile_completed: user.profile_completed,
        }
    }
}

/// Cuerpo de `POST /auth/refresh` y `POST /auth/logout`.
#[derive(Debug, Deserialize)]
pub struct RefreshRequest {
    pub refresh_token: Option<String>,
}

/// Respuesta de login y refresh.
#[derive(Debug, Serialize)]
pub struct TokenResponse {
    pub access_token: String,
    pub refresh_token: String,
    pub token_type: &'static str,
    /// Segundos de vida del access token.
    pub expires_in: i64,
    pub user: UserResponse,
}

impl TokenResponse {
    fn new(tokens: IssuedTokens, user: User) -> Self {
        Self {
            access_token: tokens.access_token,
            refresh_token: tokens.refresh_token,
            token_type: "Bearer",
            expires_in: tokens.expires_in,
            user: user.into(),
        }
    }
}

#[derive(Debug, Serialize)]
pub struct SessionResponse {
    pub user_id: String,
    pub role: Role,
}

// ---------- Handlers ----------

/// HU-01 — `POST /api/v1/auth/register`
pub async fn register_handler(
    State(state): State<AppState>,
    ApiJson(body): ApiJson<RegisterRequest>,
) -> Result<(StatusCode, Json<UserResponse>), AppError> {
    let input = RegisterInput {
        name: body.name,
        email: body.email,
        password: body.password,
        role: body.role,
        privacy_accepted: body.privacy_accepted,
    };
    let user = auth_service::register(&state.db, input).await?;
    Ok((StatusCode::CREATED, Json(user.into())))
}

/// HU-02 — `POST /api/v1/auth/login`. Abre una sesión nueva.
pub async fn login_handler(
    State(state): State<AppState>,
    ApiJson(body): ApiJson<LoginRequest>,
) -> Result<Json<TokenResponse>, AppError> {
    let user = auth_service::login(&state.db, body.email, body.password).await?;
    let tokens = session::start(&state.db, &state.tokens, &user).await?;
    Ok(Json(TokenResponse::new(tokens, user)))
}

/// HU-02 — `POST /api/v1/auth/refresh`. Rota el refresh token.
pub async fn refresh_handler(
    State(state): State<AppState>,
    ApiJson(body): ApiJson<RefreshRequest>,
) -> Result<Json<TokenResponse>, AppError> {
    let (user, tokens) = session::refresh(&state.db, &state.tokens, body.refresh_token).await?;
    Ok(Json(TokenResponse::new(tokens, user)))
}

/// HU-02 — `POST /api/v1/auth/logout`. Requiere Bearer; revoca la sesión completa.
pub async fn logout_handler(
    State(state): State<AppState>,
    auth_user: AuthenticatedUser,
    ApiJson(body): ApiJson<RefreshRequest>,
) -> Result<StatusCode, AppError> {
    session::logout(&state.db, auth_user.session_id, body.refresh_token).await?;
    Ok(StatusCode::NO_CONTENT)
}

/// HU-02 — `GET /api/v1/auth/me`. Datos de la cuenta del token.
pub async fn me_handler(
    State(state): State<AppState>,
    auth_user: AuthenticatedUser,
) -> Result<Json<UserResponse>, AppError> {
    let user = auth_service::find_user_by_id(&state.db, auth_user.user_id)
        .await?
        .ok_or(AppError::Unauthorized("La cuenta ya no existe"))?;
    Ok(Json(user.into()))
}

/// TEC-05 — `GET /api/v1/coach/test`. Prueba de la regla de acceso por rol (solo coach).
pub async fn coach_only_handler(CoachOnly(auth_user): CoachOnly) -> Json<SessionResponse> {
    Json(SessionResponse {
        user_id: auth_user.user_id.to_hex(),
        role: auth_user.role,
    })
}
