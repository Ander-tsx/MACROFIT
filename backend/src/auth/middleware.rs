use axum::{
    async_trait,
    extract::FromRequestParts,
    http::{header, request::Parts, StatusCode},
};
use jsonwebtoken::{decode, DecodingKey, Validation};
use super::jwt::Claims;

#[derive(Debug, Clone)]
pub struct AuthenticatedUser {
    pub user_id: String,
    pub role: String,
}

impl AuthenticatedUser {
    pub fn is_coach(&self) -> bool {
        self.role == "Coach"
    }

    pub fn require_coach(&self) -> Result<(), (StatusCode, &'static str)> {
        if self.is_coach() {
            Ok(())
        } else {
            Err((StatusCode::FORBIDDEN, "Acceso denegado: se requiere rol de Coach"))
        }
    }
}

#[async_trait]
impl<S> FromRequestParts<S> for AuthenticatedUser
where
    S: Send + Sync,
{
    type Rejection = (StatusCode, &'static str);

    async fn from_request_parts(parts: &mut Parts, _state: &S) -> Result<Self, Self::Rejection> {
        let auth_header = parts
            .headers
            .get(header::AUTHORIZATION)
            .and_then(|value| value.to_str().ok())
            .ok_or((StatusCode::UNAUTHORIZED, "Falta cabecera de autorización"))?;

        if !auth_header.starts_with("Bearer ") {
            return Err((StatusCode::UNAUTHORIZED, "Formato de token inválido"));
        }

        let token = &auth_header[7..];
        let secret = std::env::var("JWT_SECRET").unwrap_or_default();

        let token_data = decode::<Claims>(
            token,
            &DecodingKey::from_secret(secret.as_bytes()),
            &Validation::default(),
        )
        .map_err(|_| (StatusCode::UNAUTHORIZED, "Token inválido o expirado"))?;

        Ok(AuthenticatedUser {
            user_id: token_data.claims.sub,
            role: token_data.claims.role,
        })
    }
}

pub struct CoachOnly(pub AuthenticatedUser);

#[async_trait]
impl<S> FromRequestParts<S> for CoachOnly
where
    S: Send + Sync,
{
    type Rejection = (StatusCode, &'static str);

    async fn from_request_parts(parts: &mut Parts, state: &S) -> Result<Self, Self::Rejection> {
        let auth_user = AuthenticatedUser::from_request_parts(parts, state).await?;
        if auth_user.role != "Coach" {
            return Err((StatusCode::FORBIDDEN, "Acceso denegado: se requiere rol de Coach"));
        }
        Ok(CoachOnly(auth_user))
    }
}
