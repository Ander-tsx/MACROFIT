use mongodb::bson::{DateTime, oid::ObjectId};
use serde::{Deserialize, Serialize};

pub const GOALS_COLLECTION: &str = "goals";

/// Quién fijó la meta: el cálculo automático o un coach.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum GoalSource {
    System,
    Coach,
}

/// Meta nutricional. El historial es de solo inserción: la vigente es la de
/// `effective_from` más reciente.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NutritionalGoal {
    #[serde(rename = "_id")]
    pub id: ObjectId,
    pub user_id: ObjectId,
    pub calories: i32,
    pub protein_g: i32,
    pub fat_g: i32,
    pub source: GoalSource,
    /// Id del coach que fijó la meta (solo cuando `source` es `coach`).
    pub set_by: Option<ObjectId>,
    pub effective_from: DateTime,
    pub created_at: DateTime,
}
