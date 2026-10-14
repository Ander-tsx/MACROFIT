use mongodb::bson::oid::ObjectId;
use serde::{Deserialize, Serialize};

/// Bucket de GridFS de las fotos de comidas (TEC-13). Mongo lo guarda en dos colecciones:
/// `meal_photos.files` (un documento por foto) y `meal_photos.chunks` (el contenido en trozos).
pub const MEAL_PHOTOS_BUCKET: &str = "meal_photos";
pub const MEAL_PHOTOS_FILES_COLLECTION: &str = "meal_photos.files";
pub const MEAL_PHOTOS_CHUNKS_COLLECTION: &str = "meal_photos.chunks";

/// Formatos de imagen permitidos. Se detectan por el contenido del archivo, no por su extensión.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, utoipa::ToSchema)]
#[serde(rename_all = "lowercase")]
pub enum PhotoFormat {
    Jpeg,
    Png,
}

impl PhotoFormat {
    /// Tipo MIME de la foto (lo usa la preparación de la foto para el reconocimiento de alimentos, TEC-02).
    pub fn mime_type(self) -> &'static str {
        match self {
            Self::Jpeg => "image/jpeg",
            Self::Png => "image/png",
        }
    }
}

/// Campo `metadata` del documento de `meal_photos.files`.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MealPhotoMetadata {
    /// Usuario dueño de la foto (`users._id`).
    pub owner_id: ObjectId,
    pub format: PhotoFormat,
}
