//! HU-07 — estimación nutricional de la foto de una comida (RF-06).
//!
//! Lee la foto **propia** (HU-06 / TEC-13), la prepara y la manda al proveedor configurado mediante
//! [`FoodService`] (capa del adaptador, RNF-13). Este servicio no conoce al proveedor: solo traduce el resultado
//! del adaptador a los errores de la API. La estimación no se guarda (eso es HU-08 / HU-09).

use mongodb::{Database, bson::oid::ObjectId};

use crate::error::{AppError, FieldErrors};
use crate::services::food_recognition::{FoodEstimate, FoodService, RecognitionError, preprocess};
use crate::services::photos;

/// Estimación de una foto, lista para la respuesta.
#[derive(Debug, Clone, PartialEq)]
pub struct MealEstimate {
    pub photo_id: String,
    pub estimate: FoodEstimate,
}

/// Valida el cuerpo: `photo_id` obligatorio y no vacío. Si no es un id válido se responde 404 más adelante,
/// igual que una foto inexistente.
pub fn validate_estimate_request(photo_id: Option<String>) -> Result<String, AppError> {
    match photo_id.map(|id| id.trim().to_string()) {
        Some(id) if !id.is_empty() => Ok(id),
        _ => Err(AppError::Validation(FieldErrors::from([(
            "photo_id".to_string(),
            "Indica la foto que quieres estimar".to_string(),
        )]))),
    }
}

/// Traduce el error del adaptador al error de la API. El detalle del proveedor solo va al log.
pub fn map_recognition_error(provider: &str, err: RecognitionError) -> AppError {
    match err {
        RecognitionError::NotRecognized => AppError::FoodNotRecognized,
        RecognitionError::Provider(detail) => {
            eprintln!("[reconocimiento de alimentos] {provider}: {detail}");
            AppError::FoodProviderError
        }
        RecognitionError::Timeout => {
            eprintln!("[reconocimiento de alimentos] {provider}: tiempo de espera agotado");
            AppError::FoodProviderTimeout
        }
    }
}

/// Prepara la foto (JPEG ≤ 1000 px, en un hilo aparte porque usa CPU) y la estima con el proveedor.
pub async fn estimate_photo_bytes(
    food: &FoodService,
    bytes: Vec<u8>,
) -> Result<FoodEstimate, AppError> {
    let image = tokio::task::spawn_blocking(move || preprocess::prepare(bytes))
        .await
        .map_err(AppError::internal)?;
    food.estimate(&image)
        .await
        .map_err(|err| map_recognition_error(food.provider_name(), err))
}

/// HU-07 — estima calorías, proteína y grasa de una foto del usuario.
/// Foto inexistente, con id mal formado o de otra cuenta → `PHOTO_NOT_FOUND`.
pub async fn estimate_meal(
    db: &Database,
    food: &FoodService,
    owner_id: ObjectId,
    photo_id: Option<String>,
) -> Result<MealEstimate, AppError> {
    let photo_id = validate_estimate_request(photo_id)?;
    let photo = photos::read_own_photo(db, owner_id, &photo_id).await?;
    let estimate = estimate_photo_bytes(food, photo.bytes).await?;
    Ok(MealEstimate {
        photo_id: photo.id.to_hex(),
        estimate,
    })
}

#[cfg(test)]
mod tests {
    use std::time::Duration;

    use super::*;
    use crate::config::SimulatorMode;

    fn food(mode: SimulatorMode) -> FoodService {
        FoodService::simulator(mode, Duration::from_millis(200))
    }

    /// JPEG mínimo con la firma correcta (la preparación lo manda tal cual si no lo puede decodificar).
    fn photo() -> Vec<u8> {
        vec![0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10]
    }

    #[test]
    fn photo_id_es_obligatorio() {
        for missing in [None, Some(String::new()), Some("   ".to_string())] {
            match validate_estimate_request(missing) {
                Err(AppError::Validation(fields)) => assert!(fields.contains_key("photo_id")),
                other => panic!("se esperaba VALIDATION_ERROR, llegó {other:?}"),
            }
        }
        assert_eq!(
            validate_estimate_request(Some(" abc ".to_string())).unwrap(),
            "abc"
        );
    }

    #[tokio::test]
    async fn exito_devuelve_alimentos_y_totales() {
        let estimate = estimate_photo_bytes(&food(SimulatorMode::Ok), photo())
            .await
            .unwrap();
        assert_eq!(estimate.foods.len(), 3);
        assert!(estimate.foods.iter().all(|f| !f.name.is_empty()));
        assert_eq!(estimate.totals.calories_kcal, 413.0);
        assert_eq!(estimate.totals.protein_g, 42.2);
        assert_eq!(estimate.totals.fat_g, 4.9);
    }

    #[tokio::test]
    async fn comida_no_reconocida_es_food_not_recognized() {
        let result = estimate_photo_bytes(&food(SimulatorMode::NotRecognized), photo()).await;
        assert!(matches!(result, Err(AppError::FoodNotRecognized)));
    }

    #[tokio::test]
    async fn falla_del_servicio_es_food_provider_error() {
        let result = estimate_photo_bytes(&food(SimulatorMode::Error), photo()).await;
        assert!(matches!(result, Err(AppError::FoodProviderError)));
    }

    #[tokio::test]
    async fn tiempo_de_espera_es_food_provider_timeout() {
        let started = std::time::Instant::now();
        let result = estimate_photo_bytes(&food(SimulatorMode::Timeout), photo()).await;
        assert!(matches!(result, Err(AppError::FoodProviderTimeout)));
        assert!(started.elapsed() < Duration::from_secs(5));
    }
}
