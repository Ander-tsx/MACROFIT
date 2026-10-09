use mongodb::bson::{DateTime, oid::ObjectId};
use serde::{Deserialize, Serialize};

pub const PROFILES_COLLECTION: &str = "profiles";

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum Gender {
    Male,
    Female,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Objective {
    LoseFat,
    Maintain,
    GainMuscle,
}

/// Perfil con los datos que necesita la fórmula de la meta (HU-03 / HU-04).
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UserProfile {
    #[serde(rename = "_id")]
    pub id: ObjectId,
    pub user_id: ObjectId,
    pub weight_kg: f64,
    pub height_cm: f64,
    pub birth_date: DateTime,
    pub gender: Gender,
    /// Días de entrenamiento por semana (1 a 7).
    pub training_days: i32,
    pub objective: Objective,
    pub created_at: DateTime,
    pub updated_at: DateTime,
}
