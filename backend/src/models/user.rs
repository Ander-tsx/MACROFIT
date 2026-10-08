use mongodb::bson::{DateTime, oid::ObjectId};
use serde::{Deserialize, Serialize};

pub const USERS_COLLECTION: &str = "users";

/// Rol de la cuenta. Se guarda y se expone en minúsculas: `"user"` o `"coach"`.
#[derive(Debug, Serialize, Deserialize, PartialEq, Eq, Clone, Copy)]
#[serde(rename_all = "lowercase")]
pub enum Role {
    User,
    Coach,
}

impl Role {
    pub fn parse(value: &str) -> Option<Self> {
        match value {
            "user" => Some(Role::User),
            "coach" => Some(Role::Coach),
            _ => None,
        }
    }
}

/// Documento de la colección `users`.
///
/// Índices: `email_unique` (único sobre `email`). El correo se guarda
/// normalizado (sin espacios y en minúsculas), por eso el índice basta para
/// impedir duplicados que solo difieren en mayúsculas.
#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct User {
    #[serde(rename = "_id", skip_serializing_if = "Option::is_none")]
    pub id: Option<ObjectId>,
    pub name: String,
    pub email: String,
    pub password_hash: String,
    pub role: Role,
    /// Momento en que se aceptó el aviso de privacidad. `None` solo en cuentas creadas
    /// antes de TEC-07, cuando el aviso aún no se exigía.
    pub privacy_accepted_at: Option<DateTime>,
    /// Versión del aviso aceptada (`services::legal::PRIVACY_VERSION`).
    #[serde(default)]
    pub privacy_version: Option<String>,
    pub profile_completed: bool,
    pub created_at: DateTime,
}

impl User {
    pub fn id_hex(&self) -> String {
        self.id.map(|oid| oid.to_hex()).unwrap_or_default()
    }
}
