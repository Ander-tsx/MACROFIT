use mongodb::bson::{DateTime, oid::ObjectId};
use serde::{Deserialize, Serialize};

pub const WEIGHTS_COLLECTION: &str = "weights";

/// Registro de peso corporal (HU-21). Solo se insertan documentos; la fecha la pone el servidor.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct WeightEntry {
    #[serde(rename = "_id")]
    pub id: ObjectId,
    pub user_id: ObjectId,
    pub weight_kg: f64,
    pub recorded_at: DateTime,
}
