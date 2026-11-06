use mongodb::bson::{DateTime, oid::ObjectId};
use serde::{Deserialize, Serialize};

pub const ROUTINE_ASSIGNMENTS_COLLECTION: &str = "routine_assignments";

/// Estado de la asignación de una rutina a un cliente.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum AssignmentStatus {
    /// El cliente la ve y la sigue (HU-16, HU-17).
    Active,
    /// Retirada por el coach (HU-20) o porque se eliminó la rutina (HU-18). Se conserva como historial.
    Removed,
}

impl AssignmentStatus {
    pub fn as_str(self) -> &'static str {
        match self {
            Self::Active => "active",
            Self::Removed => "removed",
        }
    }
}

/// Documento de `routine_assignments`: rutina de un coach asignada a un cliente (HU-19, RF-23).
///
/// Forma compartida con HU-16-API (rutinas del usuario) y HU-17-API (sesiones completadas). Solo puede haber una
/// asignación `active` por rutina y cliente (índice único parcial en `db.rs`); reasignar una retirada crea otra.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RoutineAssignment {
    #[serde(rename = "_id")]
    pub id: ObjectId,
    pub routine_id: ObjectId,
    /// Dueño de la rutina.
    pub coach_id: ObjectId,
    /// `users._id` del cliente (rol `user`).
    pub client_id: ObjectId,
    pub status: AssignmentStatus,
    pub assigned_at: DateTime,
    pub updated_at: DateTime,
    /// Solo si `status` es `removed`.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub removed_at: Option<DateTime>,
}
