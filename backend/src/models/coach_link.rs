use mongodb::bson::{DateTime, oid::ObjectId};
use serde::{Deserialize, Serialize};

pub const COACH_LINKS_COLLECTION: &str = "coach_links";

/// Estado de la vinculación entre un coach y un cliente.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum LinkStatus {
    Active,
    Unlinked,
}

/// Documento de `coach_links`. Solo las vinculaciones `active` dan acceso al cliente.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CoachLink {
    #[serde(rename = "_id")]
    pub id: ObjectId,
    pub coach_id: ObjectId,
    pub user_id: ObjectId,
    pub status: LinkStatus,
    pub created_at: DateTime,
}
