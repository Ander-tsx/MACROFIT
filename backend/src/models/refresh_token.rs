use mongodb::bson::{DateTime, oid::ObjectId};
use serde::{Deserialize, Serialize};

pub const REFRESH_TOKENS_COLLECTION: &str = "refresh_tokens";

/// Documento de la colección `refresh_tokens`. Uno por cada refresh token emitido.
///
/// Todos los tokens de un mismo inicio de sesión comparten `session_id`: al rotar se
/// revoca el anterior y se crea otro con el mismo `session_id`. La sesión está activa
/// mientras tenga algún token sin revocar y sin expirar.
///
/// Índices: `token_hash_unique` (único), `session_id`, y `expires_at_ttl` (TTL: Mongo
/// borra los documentos cuando pasa `expires_at`).
#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct RefreshToken {
    #[serde(rename = "_id", skip_serializing_if = "Option::is_none")]
    pub id: Option<ObjectId>,
    pub user_id: ObjectId,
    pub session_id: ObjectId,
    /// SHA-256 (hex) del token. El token en claro solo lo conoce el cliente.
    pub token_hash: String,
    pub expires_at: DateTime,
    /// Se llena al rotar el token, al cerrar sesión o al detectar reuso.
    pub revoked_at: Option<DateTime>,
    pub created_at: DateTime,
}
