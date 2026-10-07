use jsonwebtoken::{DecodingKey, EncodingKey, Header, Validation, decode, encode};
use mongodb::bson::oid::ObjectId;
use serde::{Deserialize, Serialize};

use crate::config::TokenConfig;
use crate::error::AppError;
use crate::models::user::Role;

/// Claims del access token (JWT HS256).
#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct Claims {
    /// ID del usuario (ObjectId en hexadecimal).
    pub sub: String,
    pub role: Role,
    /// ID de la sesión (`refresh_tokens.session_id`). Permite invalidar el
    /// access token en cuanto se cierra la sesión.
    pub sid: String,
    pub iat: usize,
    pub exp: usize,
}

pub fn generate_access_token(
    user_id: ObjectId,
    role: Role,
    session_id: ObjectId,
    config: &TokenConfig,
) -> Result<String, AppError> {
    let now = chrono::Utc::now();
    let claims = Claims {
        sub: user_id.to_hex(),
        role,
        sid: session_id.to_hex(),
        iat: now.timestamp() as usize,
        exp: (now + config.access_ttl).timestamp() as usize,
    };

    encode(
        &Header::default(),
        &claims,
        &EncodingKey::from_secret(config.jwt_secret.as_bytes()),
    )
    .map_err(AppError::internal)
}

/// Verifica firma y expiración. Cualquier fallo responde 401 `UNAUTHORIZED`.
pub fn decode_access_token(token: &str, secret: &str) -> Result<Claims, AppError> {
    decode::<Claims>(
        token,
        &DecodingKey::from_secret(secret.as_bytes()),
        &Validation::default(),
    )
    .map(|data| data.claims)
    .map_err(|_| AppError::Unauthorized("Token inválido o expirado"))
}

#[cfg(test)]
mod tests {
    use super::*;

    fn config() -> TokenConfig {
        TokenConfig {
            jwt_secret: "secreto-de-prueba".into(),
            access_ttl: chrono::Duration::minutes(15),
            refresh_ttl: chrono::Duration::days(30),
        }
    }

    #[test]
    fn el_token_conserva_usuario_rol_y_sesion() {
        let (user, session) = (ObjectId::new(), ObjectId::new());
        let token = generate_access_token(user, Role::Coach, session, &config()).unwrap();
        let claims = decode_access_token(&token, "secreto-de-prueba").unwrap();
        assert_eq!(claims.sub, user.to_hex());
        assert_eq!(claims.sid, session.to_hex());
        assert_eq!(claims.role, Role::Coach);
        assert_eq!(claims.exp - claims.iat, 15 * 60);
    }

    #[test]
    fn rechaza_token_firmado_con_otro_secreto_o_alterado() {
        let token =
            generate_access_token(ObjectId::new(), Role::User, ObjectId::new(), &config()).unwrap();
        assert!(decode_access_token(&token, "otro-secreto").is_err());

        let mut altered = token.clone();
        altered.push('x');
        assert!(decode_access_token(&altered, "secreto-de-prueba").is_err());
    }
}
