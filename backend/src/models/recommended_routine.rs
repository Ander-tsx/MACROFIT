use mongodb::bson::{DateTime, oid::ObjectId};
use serde::{Deserialize, Serialize};

use crate::models::exercise::{ExerciseLevel, MuscleGroup};
use crate::models::profile::{Level, Objective};

pub const RECOMMENDED_ROUTINES_COLLECTION: &str = "recommended_routines";

/// Origen de una rutina del usuario (RN-08): `system` (recomendada, HU-15) o `coach` (asignada, HU-19).
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, utoipa::ToSchema)]
#[serde(rename_all = "lowercase")]
pub enum RoutineOrigin {
    System,
    Coach,
}

/// Estado de una rutina recomendada.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum RecommendedStatus {
    /// La vigente del usuario: solo puede haber una (índice único parcial en `db.rs`).
    Active,
    /// Reemplazada al generar otra. Se conserva para que las sesiones completadas (HU-17) sigan apuntando a ella.
    Replaced,
}

/// Ejercicio de una sesión recomendada. `name`, `muscle_group`, `equipment` y `level` son copia del catálogo.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct RecommendedExercise {
    pub exercise_id: ObjectId,
    pub name: String,
    pub muscle_group: MuscleGroup,
    pub equipment: String,
    pub level: ExerciseLevel,
    pub sets: i32,
    pub reps: i32,
    pub rest_seconds: i32,
}

/// Sesión numerada desde 1 (`Día 1 · Empuje`); no se ata a un día de la semana.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct RecommendedSession {
    pub number: i32,
    pub name: String,
    /// `full_body`, `upper`, `push`, `pull` o `legs` (`SessionFocus` del motor de TEC-10).
    pub focus: String,
    pub exercises: Vec<RecommendedExercise>,
}

/// Documento de `recommended_routines`: rutina recomendada por el sistema a un usuario (HU-15, RF-14).
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct RecommendedRoutine {
    #[serde(rename = "_id")]
    pub id: ObjectId,
    /// `users._id` (rol `user`).
    pub user_id: ObjectId,
    /// Siempre `system`.
    pub origin: RoutineOrigin,
    pub name: String,
    /// Objetivo, nivel y días del perfil con que se generó.
    pub objective: Objective,
    pub level: Level,
    pub training_days: i32,
    pub sessions: Vec<RecommendedSession>,
    pub status: RecommendedStatus,
    pub created_at: DateTime,
    /// Solo si `status` es `replaced`.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub replaced_at: Option<DateTime>,
}
