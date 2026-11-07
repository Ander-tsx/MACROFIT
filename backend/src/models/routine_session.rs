use mongodb::bson::{DateTime, oid::ObjectId};
use serde::{Deserialize, Serialize};

pub const ROUTINE_SESSIONS_COLLECTION: &str = "routine_sessions";

/// Origen de la rutina (RN-08): el mismo enum de HU-15 (`system` recomendada, `coach` asignada).
pub use crate::models::recommended_routine::RoutineOrigin;

/// Documento de `routine_sessions`: una sesión de rutina que el usuario marcó como completada (HU-17, RF-16).
///
/// Forma compartida con HU-22-API (cumplimiento semanal: sesiones por `user_id` y `date`). Guarda copia del nombre
/// de la rutina y de la sesión para conservarse aunque la rutina se edite, se regenere o se retire (RF-24): nunca se
/// borra junto con la rutina ni con la asignación. Una sola por usuario, rutina, sesión y día (índice único).
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RoutineSession {
    #[serde(rename = "_id")]
    pub id: ObjectId,
    pub user_id: ObjectId,
    /// Id de la rutina: `routines._id` (origen `coach`) o el de la rutina recomendada (origen `system`, HU-15).
    pub routine_id: ObjectId,
    pub origin: RoutineOrigin,
    /// Coach dueño de la rutina; solo con origen `coach`.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub coach_id: Option<ObjectId>,
    /// `routine_assignments._id` vigente al registrar; solo con origen `coach`.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub assignment_id: Option<ObjectId>,
    /// Copia del nombre de la rutina al registrar.
    pub routine_name: String,
    /// Número de la sesión dentro de la rutina (1 en las asignadas).
    pub session_number: i32,
    /// Copia del nombre de la sesión al registrar.
    pub session_name: String,
    /// Día de cumplimiento `YYYY-MM-DD` en hora de México (`APP_UTC_OFFSET`), igual que `meals.date`.
    pub date: String,
    /// Instante en que se registró.
    pub completed_at: DateTime,
}
