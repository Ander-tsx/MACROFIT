//! Proveedor LogMeal (API especializada en comida). Usa el token de un **APIUser** (`LOGMEAL_API_TOKEN`); el token
//! APICompany del panel solo sirve para crear usuarios.
//!
//! 1. `POST /v2/image/segmentation/complete?language=spa` (multipart, campo `image`): detecta cada platillo,
//!    lo reconoce y estima su porción (`serving_size` en gramos). Devuelve `imageId`.
//! 2. `POST /v2/nutrition/recipe/nutritionalInfo` con `{ imageId }`: valores por platillo en
//!    `nutritional_info_per_item[].nutritional_info.totalNutrients` (`ENERC_KCAL`, `PROCNT`, `FAT`).
//!
//! "No hay comida": `segmentation_results` vacío, o ningún platillo con información nutricional.
//! Plan Free: 200 imágenes en total, 20 peticiones al día por APIUser (`429`), 5 usuarios; cada estimación consume una imagen.

use std::collections::HashMap;

use async_trait::async_trait;
use reqwest::multipart::{Form, Part};
use serde_json::{Value, json};

use super::{
    FoodEstimate, FoodImage, FoodRecognizer, IdentifiedFood, Nutrients, RecognitionError,
    http_client, snippet,
};
use crate::config::Secret;

const BASE_URL: &str = "https://api.logmeal.com/v2";

pub struct LogMeal {
    client: reqwest::Client,
    token: Secret,
}

impl LogMeal {
    pub fn new(token: Secret) -> Self {
        Self {
            client: http_client(),
            token,
        }
    }

    async fn send(&self, request: reqwest::RequestBuilder) -> Result<String, RecognitionError> {
        let response = request
            .bearer_auth(self.token.expose())
            .send()
            .await
            .map_err(|err| RecognitionError::provider(format!("logmeal: {}", err.without_url())))?;
        let status = response.status();
        let body = response
            .text()
            .await
            .map_err(|err| RecognitionError::provider(format!("logmeal: {}", err.without_url())))?;
        if !status.is_success() {
            return Err(RecognitionError::provider(format!(
                "logmeal: HTTP {status}: {}",
                snippet(&body)
            )));
        }
        Ok(body)
    }
}

#[async_trait]
impl FoodRecognizer for LogMeal {
    fn name(&self) -> &'static str {
        "logmeal"
    }

    async fn recognize(&self, image: &FoodImage) -> Result<FoodEstimate, RecognitionError> {
        let part = Part::bytes(image.bytes.clone())
            .file_name(if image.mime == "image/png" {
                "foto.png"
            } else {
                "foto.jpg"
            })
            .mime_str(image.mime)
            .map_err(|err| RecognitionError::provider(format!("logmeal: {err}")))?;
        let body = self
            .send(
                self.client
                    .post(format!(
                        "{BASE_URL}/image/segmentation/complete?language=spa"
                    ))
                    .multipart(Form::new().part("image", part)),
            )
            .await?;
        let segmentation = parse_segmentation(&body)?;

        let body = self
            .send(
                self.client
                    .post(format!(
                        "{BASE_URL}/nutrition/recipe/nutritionalInfo?language=spa"
                    ))
                    .json(&json!({ "imageId": segmentation.image_id })),
            )
            .await?;
        parse_nutrition(&body, &segmentation)
    }
}

/// Lo que se usa del paso 1: el id de la imagen y el nombre más probable de cada posición.
#[derive(Debug, Clone, PartialEq)]
pub struct Segmentation {
    pub image_id: i64,
    /// `food_item_position` → nombre del platillo más probable.
    pub names: HashMap<i64, String>,
}

fn parse_json(body: &str, step: &str) -> Result<Value, RecognitionError> {
    serde_json::from_str(body).map_err(|err| {
        RecognitionError::provider(format!("logmeal ({step}): JSON inválido: {err}"))
    })
}

/// Paso 1. Sin platillos detectados → `NotRecognized`.
pub fn parse_segmentation(body: &str) -> Result<Segmentation, RecognitionError> {
    let value = parse_json(body, "segmentación")?;
    let image_id = value["imageId"]
        .as_i64()
        .ok_or_else(|| RecognitionError::provider("logmeal (segmentación): falta imageId"))?;
    let items = value["segmentation_results"]
        .as_array()
        .cloned()
        .unwrap_or_default();
    let names: HashMap<i64, String> = items
        .iter()
        .filter_map(|item| {
            let position = item["food_item_position"].as_i64()?;
            let name = item["recognition_results"][0]["name"].as_str()?;
            Some((position, name.to_string()))
        })
        .collect();
    if names.is_empty() {
        return Err(RecognitionError::NotRecognized);
    }
    Ok(Segmentation { image_id, names })
}

/// Cantidad de un nutriente (`ENERC_KCAL`, `PROCNT`, `FAT`) dentro de `nutritional_info`; 0 si no viene.
fn nutrient(info: &Value, code: &str) -> f64 {
    info["totalNutrients"][code]["quantity"]
        .as_f64()
        .unwrap_or(0.0)
}

fn truthy(value: &Value) -> bool {
    value.as_bool().unwrap_or_else(|| value.as_i64() == Some(1))
}

/// Paso 2. Usa los valores por platillo; los que no tienen información nutricional se omiten.
pub fn parse_nutrition(
    body: &str,
    segmentation: &Segmentation,
) -> Result<FoodEstimate, RecognitionError> {
    let value = parse_json(body, "nutrición")?;
    if !truthy(&value["hasNutritionalInfo"]) {
        return Err(RecognitionError::NotRecognized);
    }
    let food_names: Vec<String> = match &value["foodName"] {
        Value::Array(names) => names
            .iter()
            .filter_map(|n| n.as_str().map(str::to_string))
            .collect(),
        Value::String(name) => vec![name.clone()],
        _ => Vec::new(),
    };

    let foods: Vec<IdentifiedFood> = match value["nutritional_info_per_item"].as_array() {
        Some(items) if !items.is_empty() => items
            .iter()
            .enumerate()
            .filter(|(_, item)| truthy(&item["hasNutritionalInfo"]))
            .map(|(index, item)| {
                let name = item["food_item_position"]
                    .as_i64()
                    .and_then(|position| segmentation.names.get(&position).cloned())
                    .or_else(|| food_names.get(index).cloned())
                    .unwrap_or_else(|| "Alimento".to_string());
                let info = &item["nutritional_info"];
                IdentifiedFood {
                    name,
                    grams: item["serving_size"].as_f64(),
                    nutrients: Nutrients {
                        calories_kcal: nutrient(info, "ENERC_KCAL"),
                        protein_g: nutrient(info, "PROCNT"),
                        fat_g: nutrient(info, "FAT"),
                    },
                }
            })
            .collect(),
        // Sin desglose: un solo alimento con los valores totales.
        _ => {
            let info = &value["nutritional_info"];
            vec![IdentifiedFood {
                name: if food_names.is_empty() {
                    "Alimento".to_string()
                } else {
                    food_names.join(", ")
                },
                grams: value["serving_size"].as_f64(),
                nutrients: Nutrients {
                    calories_kcal: nutrient(info, "ENERC_KCAL"),
                    protein_g: nutrient(info, "PROCNT"),
                    fat_g: nutrient(info, "FAT"),
                },
            }]
        }
    };
    FoodEstimate::from_foods(foods)
}

#[cfg(test)]
mod tests {
    use super::*;

    const SEGMENTATION: &str = include_str!("fixtures/logmeal_segmentation.json");
    const SEGMENTATION_EMPTY: &str = include_str!("fixtures/logmeal_segmentation_empty.json");
    const NUTRITION: &str = include_str!("fixtures/logmeal_nutrition.json");

    #[test]
    fn la_segmentacion_da_el_id_y_el_nombre_mas_probable() {
        let segmentation = parse_segmentation(SEGMENTATION).unwrap();
        assert_eq!(segmentation.image_id, 1234567);
        assert_eq!(segmentation.names[&1], "chilaquiles verdes");
        assert_eq!(segmentation.names[&2], "frijoles refritos");
    }

    #[test]
    fn segmentacion_sin_platillos_no_se_reconoce() {
        assert_eq!(
            parse_segmentation(SEGMENTATION_EMPTY),
            Err(RecognitionError::NotRecognized)
        );
    }

    #[test]
    fn la_nutricion_se_toma_por_platillo() {
        let segmentation = parse_segmentation(SEGMENTATION).unwrap();
        let estimate = parse_nutrition(NUTRITION, &segmentation).unwrap();
        // El tercer elemento no tiene información nutricional y se omite.
        assert_eq!(estimate.foods.len(), 2);
        assert_eq!(estimate.foods[0].name, "chilaquiles verdes");
        assert_eq!(estimate.foods[0].grams, Some(280.0));
        assert_eq!(estimate.foods[1].name, "frijoles refritos");
        assert_eq!(
            estimate.totals,
            Nutrients {
                calories_kcal: 645.5,
                protein_g: 22.4,
                fat_g: 30.1
            }
        );
    }

    #[test]
    fn sin_informacion_nutricional_no_se_reconoce() {
        let segmentation = parse_segmentation(SEGMENTATION).unwrap();
        let body = r#"{"hasNutritionalInfo": false, "imageId": 1234567, "foodName": ["objeto"]}"#;
        assert_eq!(
            parse_nutrition(body, &segmentation),
            Err(RecognitionError::NotRecognized)
        );
    }

    #[test]
    fn sin_desglose_usa_los_totales() {
        let segmentation = parse_segmentation(SEGMENTATION).unwrap();
        let body = r#"{"hasNutritionalInfo": true, "foodName": "pozole", "serving_size": 400,
            "nutritional_info": {"calories": 380, "totalNutrients": {
              "ENERC_KCAL": {"quantity": 380, "unit": "kcal"},
              "PROCNT": {"quantity": 25, "unit": "g"},
              "FAT": {"quantity": 12, "unit": "g"}}}}"#;
        let estimate = parse_nutrition(body, &segmentation).unwrap();
        assert_eq!(estimate.foods.len(), 1);
        assert_eq!(estimate.foods[0].name, "pozole");
        assert_eq!(estimate.totals.calories_kcal, 380.0);
    }

    #[test]
    fn json_invalido_es_falla_del_servicio() {
        assert!(matches!(
            parse_segmentation("<html>"),
            Err(RecognitionError::Provider(_))
        ));
        assert!(matches!(
            parse_segmentation(r#"{"segmentation_results": []}"#),
            Err(RecognitionError::Provider(_))
        ));
    }
}
