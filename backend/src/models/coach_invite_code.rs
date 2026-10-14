use mongodb::bson::{DateTime, oid::ObjectId};
use serde::{Deserialize, Serialize};

pub const COACH_INVITE_CODES_COLLECTION: &str = "coach_invite_codes";

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CoachInviteCode {
    #[serde(rename = "_id")]
    pub id: ObjectId,
    pub coach_id: ObjectId,
    pub code: String,
    pub created_at: DateTime,
    pub updated_at: DateTime,
}
