use mongodb::bson::{DateTime, oid::ObjectId};
use serde::{Deserialize, Serialize};

pub const PROFILES_COLLECTION: &str = "profiles";

/// Sexo biológico que usa la fórmula de la meta (HU-04). Se guarda en minúsculas.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum Gender {
    Male,
    Female,
}

impl Gender {
    pub fn parse(value: &str) -> Option<Self> {
        match value {
            "male" => Some(Self::Male),
            "female" => Some(Self::Female),
            _ => None,
        }
    }
}

/// Objetivo del usuario. Se guarda en `snake_case`: `lose_fat`, `maintain`, `gain_muscle`.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Objective {
    LoseFat,
    Maintain,
    GainMuscle,
}

impl Objective {
    pub fn parse(value: &str) -> Option<Self> {
        match value {
            "lose_fat" => Some(Self::LoseFat),
            "maintain" => Some(Self::Maintain),
            "gain_muscle" => Some(Self::GainMuscle),
            _ => None,
        }
    }
}

/// Nivel de entrenamiento: `beginner`, `intermediate`, `advanced`.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum Level {
    Beginner,
    Intermediate,
    Advanced,
}

impl Level {
    pub fn parse(value: &str) -> Option<Self> {
        match value {
            "beginner" => Some(Self::Beginner),
            "intermediate" => Some(Self::Intermediate),
            "advanced" => Some(Self::Advanced),
            _ => None,
        }
    }
}

/// Documento de la colección `profiles` (HU-03). Un perfil por usuario.
///
/// Índices: `user_id_unique` (único sobre `user_id`).
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UserProfile {
    #[serde(rename = "_id")]
    pub id: ObjectId,
    pub user_id: ObjectId,
    pub objective: Objective,
    pub level: Level,
    /// Días de entrenamiento por semana (1 a 7).
    pub training_days: i32,
    pub weight_kg: f64,
    pub height_cm: f64,
    pub gender: Gender,
    /// Fecha de nacimiento a medianoche UTC.
    pub birth_date: DateTime,
    pub created_at: DateTime,
    pub updated_at: DateTime,
}
