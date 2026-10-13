use axum::{
    Json, Router,
    extract::State,
    http::StatusCode,
    routing::{get, post},
};
use serde::{Deserialize, Serialize};
use utoipa::ToSchema;

use crate::auth::middleware::{AuthenticatedUser, CoachOnly};
use crate::error::{ApiJson, AppError, ErrorResponse};
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
#[derive(Debug, Deserialize, ToSchema)]
#[schema(description = "Datos de la cuenta nueva. Todos los campos son obligatorios.")]
pub struct RegisterRequest {
    /// No vacío tras quitar espacios; máximo 100 caracteres.
    #[schema(value_type = String, required = true, example = "Ana")]
    pub name: Option<String>,
    /// Formato válido, máximo 254. Se guarda en minúsculas y sin espacios.
    #[schema(value_type = String, required = true, example = "ana@macrofit.com")]
    pub email: Option<String>,
    /// De 8 a 128 caracteres. Se guarda solo como hash Argon2id.
    #[schema(value_type = String, required = true, example = "MinimoOcho")]
    pub password: Option<String>,
    /// `user` o `coach` (exacto, en minúsculas).
    #[schema(value_type = Role, required = true)]
    pub role: Option<String>,
    /// Debe ser `true`: aceptación del aviso de privacidad vigente.
    #[schema(value_type = bool, required = true, example = true)]
    pub privacy_accepted: Option<bool>,
}

/// Cuerpo de `POST /auth/login`.
#[derive(Debug, Deserialize, ToSchema)]
pub struct LoginRequest {
    #[schema(value_type = String, required = true, example = "ana@macrofit.com")]
    pub email: Option<String>,
    #[schema(value_type = String, required = true, example = "MinimoOcho")]
    pub password: Option<String>,
}

/// Representación pública de una cuenta. Nunca incluye la contraseña ni su hash.
#[derive(Debug, Serialize, ToSchema)]
pub struct UserResponse {
    #[schema(example = "6ac67c70a1b2c3d4e5f60718")]
    pub id: String,
    #[schema(example = "Ana")]
    pub name: String,
    #[schema(example = "ana@macrofit.com")]
    pub email: String,
    pub role: Role,
    /// `true` cuando el usuario ya capturó su perfil inicial (HU-03).
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
#[derive(Debug, Deserialize, ToSchema)]
pub struct RefreshRequest {
    /// Refresh token opaco de la sesión (64 caracteres hexadecimales).
    #[schema(value_type = String, required = true)]
    pub refresh_token: Option<String>,
}

/// Respuesta de login y refresh.
#[derive(Debug, Serialize, ToSchema)]
pub struct TokenResponse {
    /// JWT para `Authorization: Bearer <token>`.
    pub access_token: String,
    /// Valor opaco para `/auth/refresh` y `/auth/logout`. Se rota en cada renovación.
    pub refresh_token: String,
    #[schema(example = "Bearer")]
    pub token_type: &'static str,
    /// Segundos de vida del access token.
    #[schema(example = 900)]
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

#[derive(Debug, Serialize, ToSchema)]
pub struct SessionResponse {
    pub user_id: String,
    pub role: Role,
}

// ---------- Handlers ----------

/// HU-01 — `POST /api/v1/auth/register`
#[utoipa::path(
    post,
    path = "/auth/register",
    tag = "Autenticación",
    summary = "Crea una cuenta con rol",
    description = "Registra una cuenta `user` o `coach`. La confirmación de contraseña la valida la app.",
    request_body = RegisterRequest,
    responses(
        (status = 201, description = "Cuenta creada", body = UserResponse),
        (status = 400, description = "`VALIDATION_ERROR` (cada campo inválido en `fields`), `PRIVACY_NOT_ACCEPTED` (resto de campos válido) o `INVALID_BODY`", body = ErrorResponse),
        (status = 409, description = "`EMAIL_ALREADY_EXISTS` (también si el correo solo difiere en mayúsculas)", body = ErrorResponse),
    )
)]
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
#[utoipa::path(
    post,
    path = "/auth/login",
    tag = "Autenticación",
    summary = "Abre una sesión",
    description = "Entrega un access token (JWT, 15 min) y un refresh token (30 días, se rota en cada renovación).",
    request_body = LoginRequest,
    responses(
        (status = 200, description = "Sesión abierta", body = TokenResponse),
        (status = 400, description = "`VALIDATION_ERROR` o `INVALID_BODY`", body = ErrorResponse),
        (status = 401, description = "`INVALID_CREDENTIALS` (mismo código si el correo no existe o la contraseña es incorrecta)", body = ErrorResponse),
    )
)]
pub async fn login_handler(
    State(state): State<AppState>,
    ApiJson(body): ApiJson<LoginRequest>,
) -> Result<Json<TokenResponse>, AppError> {
    let user = auth_service::login(&state.db, body.email, body.password).await?;
    let tokens = session::start(&state.db, &state.tokens, &user).await?;
    Ok(Json(TokenResponse::new(tokens, user)))
}

/// HU-02 — `POST /api/v1/auth/refresh`. Rota el refresh token.
#[utoipa::path(
    post,
    path = "/auth/refresh",
    tag = "Autenticación",
    summary = "Renueva los tokens",
    description = "Revoca el refresh token usado y entrega tokens nuevos en la misma sesión. Presentar un refresh token ya revocado revoca la sesión completa.",
    request_body = RefreshRequest,
    responses(
        (status = 200, description = "Tokens nuevos", body = TokenResponse),
        (status = 400, description = "`VALIDATION_ERROR` o `INVALID_BODY`", body = ErrorResponse),
        (status = 401, description = "`INVALID_REFRESH_TOKEN` (desconocido o expirado) o `TOKEN_REVOKED` (ya rotado o sesión cerrada; revoca la sesión)", body = ErrorResponse),
    )
)]
pub async fn refresh_handler(
    State(state): State<AppState>,
    ApiJson(body): ApiJson<RefreshRequest>,
) -> Result<Json<TokenResponse>, AppError> {
    let (user, tokens) = session::refresh(&state.db, &state.tokens, body.refresh_token).await?;
    Ok(Json(TokenResponse::new(tokens, user)))
}

/// HU-02 — `POST /api/v1/auth/logout`. Requiere Bearer; revoca la sesión completa.
#[utoipa::path(
    post,
    path = "/auth/logout",
    tag = "Autenticación",
    summary = "Cierra la sesión",
    description = "Revoca todos los refresh tokens de la sesión; el access token deja de funcionar al instante. Cualquier rol.",
    security(("bearer_auth" = [])),
    request_body = RefreshRequest,
    responses(
        (status = 204, description = "Sesión cerrada"),
        (status = 400, description = "`VALIDATION_ERROR` o `INVALID_BODY`", body = ErrorResponse),
        (status = 401, description = "`UNAUTHORIZED` (sin token, alterado o expirado), `TOKEN_REVOKED` (sesión ya cerrada) o `INVALID_REFRESH_TOKEN` (el refresh token no es de esta sesión)", body = ErrorResponse),
    )
)]
pub async fn logout_handler(
    State(state): State<AppState>,
    auth_user: AuthenticatedUser,
    ApiJson(body): ApiJson<RefreshRequest>,
) -> Result<StatusCode, AppError> {
    session::logout(&state.db, auth_user.session_id, body.refresh_token).await?;
    Ok(StatusCode::NO_CONTENT)
}

/// HU-02 — `GET /api/v1/auth/me`. Datos de la cuenta del token.
#[utoipa::path(
    get,
    path = "/auth/me",
    tag = "Autenticación",
    summary = "Cuenta de la sesión",
    description = "Datos y rol de la cuenta del token. Cualquier rol.",
    security(("bearer_auth" = [])),
    responses(
        (status = 200, description = "Cuenta de la sesión", body = UserResponse),
        (status = 401, description = "`UNAUTHORIZED` (sin token, alterado o expirado) o `TOKEN_REVOKED` (sesión cerrada)", body = ErrorResponse),
    )
)]
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
#[utoipa::path(
    get,
    path = "/coach/test",
    tag = "Coach",
    summary = "Prueba de acceso por rol",
    description = "Responde solo a cuentas `coach`. Sirve para comprobar la regla de acceso por rol.",
    security(("bearer_auth" = ["coach"])),
    responses(
        (status = 200, description = "Sesión de coach", body = SessionResponse),
        (status = 401, description = "`UNAUTHORIZED` o `TOKEN_REVOKED`", body = ErrorResponse),
        (status = 403, description = "`FORBIDDEN_ROLE` (cuenta `user`)", body = ErrorResponse),
    )
)]
pub async fn coach_only_handler(CoachOnly(auth_user): CoachOnly) -> Json<SessionResponse> {
    Json(SessionResponse {
        user_id: auth_user.user_id.to_hex(),
        role: auth_user.role,
    })
}
