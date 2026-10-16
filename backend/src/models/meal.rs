use mongodb::bson::{DateTime, oid::ObjectId};
use serde::{Deserialize, Serialize};

pub const MEALS_COLLECTION: &str = "meals";

/// Registro de comida (HU-09, RF-08). La fecha y hora las pone el servidor al guardar.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Meal {
    #[serde(rename = "_id")]
    pub id: ObjectId,
    pub user_id: ObjectId,
    /// Foto del registro en el bucket `meal_photos` (TEC-13). Ausente en una captura manual sin foto.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub photo_id: Option<ObjectId>,
    /// Momento del registro (UTC).
    pub eaten_at: DateTime,
    /// Día del registro `YYYY-MM-DD` en la zona horaria de la app (`APP_UTC_OFFSET`). Es el que filtra `?date=`.
    pub date: String,
    /// Valores finales del registro.
    // TODO(HU-08): agregar los valores estimados (`estimated`) junto a estos finales.
    pub calories_kcal: f64,
    pub protein_g: f64,
    pub fat_g: f64,
}
