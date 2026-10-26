use mongodb::bson::{DateTime, oid::ObjectId};
use serde::{Deserialize, Serialize};

use crate::models::exercise::MuscleGroup;

pub const ROUTINES_COLLECTION: &str = "routines";

/// Ejercicio del catálogo (TEC-09) dentro de una rutina del coach, con su volumen.
/// `name` y `muscle_group` son una copia del catálogo al guardar la rutina.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct RoutineExercise {
    pub exercise_id: ObjectId,
    pub name: String,
    pub muscle_group: MuscleGroup,
    pub sets: i32,
    pub reps: i32,
    pub rest_seconds: i32,
}

/// Documento de la colección `routines`: rutina personalizada de un coach (HU-18, RF-22).
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Routine {
    #[serde(rename = "_id")]
    pub id: ObjectId,
    pub coach_id: ObjectId,
    pub name: String,
    pub exercises: Vec<RoutineExercise>,
    pub created_at: DateTime,
    pub updated_at: DateTime,
}
