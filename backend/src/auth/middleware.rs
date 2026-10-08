use axum::{
    async_trait,
    extract::FromRequestParts,
    http::{header, request::Parts},
};
use mongodb::bson::oid::ObjectId;

use super::jwt::decode_access_token;
use crate::error::AppError;
use crate::models::user::Role;
use crate::services::session;
use crate::state::AppState;

/// Extractor para rutas que requieren sesión: agrégalo como argumento del handler.
///
/// - Sin cabecera, formato incorrecto, firma alterada o token expirado → 401 `UNAUTHORIZED`.
/// - Sesión cerrada o revocada → 401 `TOKEN_REVOKED` (consulta `refresh_tokens`).
#[derive(Debug, Clone)]
pub struct AuthenticatedUser {
    pub user_id: ObjectId,
    pub role: Role,
    pub session_id: ObjectId,
}

#[async_trait]
impl FromRequestParts<AppState> for AuthenticatedUser {
    type Rejection = AppError;

    async fn from_request_parts(
        parts: &mut Parts,
        state: &AppState,
    ) -> Result<Self, Self::Rejection> {
        let token = parts
            .headers
            .get(header::AUTHORIZATION)
            .and_then(|value| value.to_str().ok())
            .ok_or(AppError::Unauthorized("Falta cabecera de autorización"))?
            .strip_prefix("Bearer ")
            .ok_or(AppError::Unauthorized("Formato de token inválido"))?;

        let claims = decode_access_token(token, &state.tokens.jwt_secret)?;
        let invalid = || AppError::Unauthorized("Token inválido o expirado");
        let user_id = ObjectId::parse_str(&claims.sub).map_err(|_| invalid())?;
        let session_id = ObjectId::parse_str(&claims.sid).map_err(|_| invalid())?;

        if !session::is_active(&state.db, session_id).await? {
            return Err(AppError::TokenRevoked);
        }

        Ok(AuthenticatedUser {
            user_id,
            role: claims.role,
            session_id,
        })
    }
}

/// Extractor para rutas exclusivas del rol `coach`; responde 403 a cualquier otro rol.
pub struct CoachOnly(pub AuthenticatedUser);

#[async_trait]
impl FromRequestParts<AppState> for CoachOnly {
    type Rejection = AppError;

    async fn from_request_parts(
        parts: &mut Parts,
        state: &AppState,
    ) -> Result<Self, Self::Rejection> {
        let auth_user = AuthenticatedUser::from_request_parts(parts, state).await?;
        if auth_user.role != Role::Coach {
            return Err(AppError::Forbidden(
                "Acceso denegado: se requiere rol de coach",
            ));
        }
        Ok(CoachOnly(auth_user))
    }
}

/// Extractor para rutas exclusivas del rol `user`; responde 403 a los coaches.
pub struct UserOnly(pub AuthenticatedUser);

#[async_trait]
impl FromRequestParts<AppState> for UserOnly {
    type Rejection = AppError;

    async fn from_request_parts(
        parts: &mut Parts,
        state: &AppState,
    ) -> Result<Self, Self::Rejection> {
        let auth_user = AuthenticatedUser::from_request_parts(parts, state).await?;
        if auth_user.role != Role::User {
            return Err(AppError::Forbidden(
                "Acceso denegado: esta función es exclusiva para usuarios",
            ));
        }
        Ok(UserOnly(auth_user))
    }
}
