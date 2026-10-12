//! HU-02: sesiones. Una sesión nace en el login y se identifica con `session_id`.
//! Cada renovación rota el refresh token (revoca el anterior y emite uno nuevo en la
//! misma sesión). Presentar un refresh token ya revocado se trata como posible robo
//! y revoca la sesión completa.

use mongodb::{
    Collection, Database,
    bson::{DateTime, doc, oid::ObjectId},
};

use crate::auth::jwt::generate_access_token;
use crate::auth::refresh::{generate_refresh_token, hash_refresh_token};
use crate::config::TokenConfig;
use crate::error::{AppError, FieldErrors};
use crate::models::refresh_token::{REFRESH_TOKENS_COLLECTION, RefreshToken};
use crate::models::user::User;
use crate::services::auth::find_user_by_id;

/// Tokens que se entregan al cliente.
pub struct IssuedTokens {
    pub access_token: String,
    pub refresh_token: String,
    /// Segundos de vida del access token.
    pub expires_in: i64,
}

fn collection(db: &Database) -> Collection<RefreshToken> {
    db.collection(REFRESH_TOKENS_COLLECTION)
}

/// Abre una sesión nueva para el usuario (login).
pub async fn start(
    db: &Database,
    config: &TokenConfig,
    user: &User,
) -> Result<IssuedTokens, AppError> {
    issue(db, config, user, ObjectId::new()).await
}

/// Rota el refresh token: lo revoca y emite tokens nuevos en la misma sesión.
pub async fn refresh(
    db: &Database,
    config: &TokenConfig,
    refresh_token: Option<String>,
) -> Result<(User, IssuedTokens), AppError> {
    let hash = hash_refresh_token(&required_refresh_token(refresh_token)?);
    let now = DateTime::now();

    // Revocar y leer en una sola operación atómica: si dos peticiones usan el mismo
    // token a la vez, solo una lo consigue y la otra cae en la detección de reuso.
    let consumed = collection(db)
        .find_one_and_update(
            doc! { "token_hash": &hash, "revoked_at": null, "expires_at": { "$gt": now } },
            doc! { "$set": { "revoked_at": now } },
        )
        .await
        .map_err(AppError::internal)?;

    let Some(current) = consumed else {
        return Err(reject_unusable_token(db, &hash).await?);
    };

    let user = find_user_by_id(db, current.user_id)
        .await?
        .ok_or(AppError::InvalidRefreshToken)?;
    let tokens = issue(db, config, &user, current.session_id).await?;
    Ok((user, tokens))
}

/// Cierra la sesión del access token. El refresh token enviado debe pertenecer a ella.
pub async fn logout(
    db: &Database,
    session_id: ObjectId,
    refresh_token: Option<String>,
) -> Result<(), AppError> {
    let hash = hash_refresh_token(&required_refresh_token(refresh_token)?);
    let belongs_to_session = collection(db)
        .find_one(doc! { "token_hash": &hash, "session_id": session_id })
        .await
        .map_err(AppError::internal)?
        .is_some();
    if !belongs_to_session {
        return Err(AppError::InvalidRefreshToken);
    }
    revoke(db, session_id).await
}

/// Una sesión está activa si tiene algún refresh token sin revocar y sin expirar.
pub async fn is_active(db: &Database, session_id: ObjectId) -> Result<bool, AppError> {
    collection(db)
        .find_one(doc! {
            "session_id": session_id,
            "revoked_at": null,
            "expires_at": { "$gt": DateTime::now() },
        })
        .await
        .map(|token| token.is_some())
        .map_err(AppError::internal)
}

async fn issue(
    db: &Database,
    config: &TokenConfig,
    user: &User,
    session_id: ObjectId,
) -> Result<IssuedTokens, AppError> {
    let user_id = user
        .id
        .ok_or_else(|| AppError::internal("usuario sin _id"))?;
    let refresh = generate_refresh_token();
    let now = DateTime::now();

    collection(db)
        .insert_one(RefreshToken {
            id: None,
            user_id,
            session_id,
            token_hash: refresh.hash,
            expires_at: DateTime::from_millis(
                now.timestamp_millis() + config.refresh_ttl.num_milliseconds(),
            ),
            revoked_at: None,
            created_at: now,
        })
        .await
        .map_err(AppError::internal)?;

    Ok(IssuedTokens {
        access_token: generate_access_token(user_id, user.role, session_id, config)?,
        refresh_token: refresh.token,
        expires_in: config.access_ttl.num_seconds(),
    })
}

/// Decide el error para un refresh token que no se pudo consumir.
async fn reject_unusable_token(db: &Database, hash: &str) -> Result<AppError, AppError> {
    let stored = collection(db)
        .find_one(doc! { "token_hash": hash })
        .await
        .map_err(AppError::internal)?;

    Ok(match stored {
        // Ya revocado (rotado o sesión cerrada): posible robo → revocar toda la sesión.
        Some(token) if token.revoked_at.is_some() => {
            revoke(db, token.session_id).await?;
            AppError::TokenRevoked
        }
        // Expirado o inexistente.
        _ => AppError::InvalidRefreshToken,
    })
}

async fn revoke(db: &Database, session_id: ObjectId) -> Result<(), AppError> {
    collection(db)
        .update_many(
            doc! { "session_id": session_id, "revoked_at": null },
            doc! { "$set": { "revoked_at": DateTime::now() } },
        )
        .await
        .map(|_| ())
        .map_err(AppError::internal)
}

fn required_refresh_token(refresh_token: Option<String>) -> Result<String, AppError> {
    match refresh_token {
        Some(token) if !token.is_empty() => Ok(token),
        _ => Err(AppError::Validation(FieldErrors::from([(
            "refresh_token".to_string(),
            "El token de actualización es obligatorio".to_string(),
        )]))),
    }
}
