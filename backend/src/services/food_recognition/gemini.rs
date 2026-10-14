//! Proveedor Gemini (Google AI Studio): un modelo multimodal analiza la foto y responde JSON con un esquema fijo.
//!
//! - `POST https://generativelanguage.googleapis.com/v1beta/models/{GEMINI_MODEL}:generateContent`
//! - Llave en la cabecera `x-goog-api-key` (nunca en la URL, para que no aparezca en logs).
//! - La foto va en línea (base64) y `generationConfig.responseSchema` obliga la forma de la respuesta:
//!   `{ recognized, foods: [{ name, name_en, grams, calories_kcal, protein_g, fat_g }] }`.
//! - "No hay comida": `recognized = false` o `foods` vacío.
//!
//! Plan gratuito: sin tarjeta, con límites por minuto y por día que se ven en AI Studio. Google puede usar lo que se
//! envía en el plan gratuito para mejorar sus modelos (ver el spike de TEC-02).

use async_trait::async_trait;
use base64::Engine;
use serde::Deserialize;
use serde_json::{Value, json};

use super::{
    FoodEstimate, FoodImage, FoodRecognizer, IdentifiedFood, Nutrients, RecognitionError,
    http_client, snippet,
};
use crate::config::Secret;

const BASE_URL: &str = "https://generativelanguage.googleapis.com/v1beta/models";

const PROMPT: &str = "Eres un nutriólogo. Analiza la foto de una comida.\n\
1. Identifica cada alimento o platillo visible por separado (por ejemplo: tortillas, frijoles, arroz, carne).\n\
2. Estima el peso en gramos de la porción que se ve de cada uno.\n\
3. Para esa porción estima calorías (kcal), proteína (g) y grasa (g).\n\
4. `name` en español de México; `name_en` es el nombre genérico en inglés para buscarlo en una base nutricional \
(por ejemplo \"refried beans\", \"corn tortilla\").\n\
Si la foto no muestra comida o bebida, responde recognized=false y foods vacío. No inventes alimentos que no se ven.";

/// Alimento tal como lo describe Gemini.
#[derive(Debug, Clone, PartialEq, Deserialize)]
pub struct GeminiFood {
    pub name: String,
    #[serde(default)]
    pub name_en: Option<String>,
    #[serde(default)]
    pub grams: Option<f64>,
    #[serde(default)]
    pub calories_kcal: f64,
    #[serde(default)]
    pub protein_g: f64,
    #[serde(default)]
    pub fat_g: f64,
}

impl From<GeminiFood> for IdentifiedFood {
    fn from(food: GeminiFood) -> Self {
        IdentifiedFood {
            name: food.name,
            grams: food.grams,
            nutrients: Nutrients {
                calories_kcal: food.calories_kcal,
                protein_g: food.protein_g,
                fat_g: food.fat_g,
            },
        }
    }
}

#[derive(Debug, Deserialize)]
struct GeminiAnswer {
    recognized: bool,
    #[serde(default)]
    foods: Vec<GeminiFood>,
}

pub struct Gemini {
    client: reqwest::Client,
    api_key: Secret,
    model: String,
}

impl Gemini {
    pub fn new(api_key: Secret, model: String) -> Self {
        Self {
            client: http_client(),
            api_key,
            model,
        }
    }

    /// Alimentos que Gemini ve en la foto (los usa también el híbrido con FatSecret).
    pub async fn identify(&self, image: &FoodImage) -> Result<Vec<GeminiFood>, RecognitionError> {
        let url = format!("{BASE_URL}/{}:generateContent", self.model);
        let response = self
            .client
            .post(url)
            .header("x-goog-api-key", self.api_key.expose())
            .json(&request_body(image))
            .send()
            .await
            .map_err(|err| RecognitionError::provider(format!("gemini: {}", err.without_url())))?;
        let status = response.status();
        let body = response
            .text()
            .await
            .map_err(|err| RecognitionError::provider(format!("gemini: {}", err.without_url())))?;
        if !status.is_success() {
            return Err(RecognitionError::provider(format!(
                "gemini: HTTP {status}: {}",
                snippet(&body)
            )));
        }
        parse_response(&body)
    }
}

#[async_trait]
impl FoodRecognizer for Gemini {
    fn name(&self) -> &'static str {
        "gemini"
    }

    async fn recognize(&self, image: &FoodImage) -> Result<FoodEstimate, RecognitionError> {
        let foods = self.identify(image).await?;
        FoodEstimate::from_foods(foods.into_iter().map(IdentifiedFood::from).collect())
    }
}

/// Cuerpo de `generateContent`: la foto, las instrucciones y el esquema de la respuesta.
pub fn request_body(image: &FoodImage) -> Value {
    let data = base64::engine::general_purpose::STANDARD.encode(&image.bytes);
    json!({
        "contents": [{
            "parts": [
                { "inline_data": { "mime_type": image.mime, "data": data } },
                { "text": PROMPT }
            ]
        }],
        "generationConfig": {
            "temperature": 0,
            "responseMimeType": "application/json",
            "responseSchema": {
                "type": "OBJECT",
                "properties": {
                    "recognized": { "type": "BOOLEAN" },
                    "foods": {
                        "type": "ARRAY",
                        "items": {
                            "type": "OBJECT",
                            "properties": {
                                "name": { "type": "STRING" },
                                "name_en": { "type": "STRING" },
                                "grams": { "type": "NUMBER" },
                                "calories_kcal": { "type": "NUMBER" },
                                "protein_g": { "type": "NUMBER" },
                                "fat_g": { "type": "NUMBER" }
                            },
                            "required": ["name", "name_en", "grams", "calories_kcal", "protein_g", "fat_g"]
                        }
                    }
                },
                "required": ["recognized", "foods"]
            }
        }
    })
}

/// Interpreta la respuesta de `generateContent`. Sin comida → `NotRecognized`; forma inesperada → `Provider`.
pub fn parse_response(body: &str) -> Result<Vec<GeminiFood>, RecognitionError> {
    let value: Value = serde_json::from_str(body)
        .map_err(|err| RecognitionError::provider(format!("gemini: JSON inválido: {err}")))?;

    if let Some(reason) = value["promptFeedback"]["blockReason"].as_str() {
        return Err(RecognitionError::provider(format!(
            "gemini: petición bloqueada ({reason})"
        )));
    }
    let candidate = &value["candidates"][0];
    let text: String = candidate["content"]["parts"]
        .as_array()
        .map(|parts| parts.iter().filter_map(|p| p["text"].as_str()).collect())
        .unwrap_or_default();
    if text.trim().is_empty() {
        let reason = candidate["finishReason"]
            .as_str()
            .unwrap_or("sin candidato");
        return Err(RecognitionError::provider(format!(
            "gemini: respuesta sin texto ({reason})"
        )));
    }

    let answer: GeminiAnswer = serde_json::from_str(text.trim()).map_err(|err| {
        RecognitionError::provider(format!("gemini: el texto no sigue el esquema: {err}"))
    })?;
    if !answer.recognized || answer.foods.is_empty() {
        return Err(RecognitionError::NotRecognized);
    }
    Ok(answer.foods)
}

#[cfg(test)]
mod tests {
    use super::*;

    const OK: &str = include_str!("fixtures/gemini_ok.json");
    const NO_FOOD: &str = include_str!("fixtures/gemini_no_food.json");

    #[test]
    fn la_peticion_lleva_la_foto_y_el_esquema() {
        let image = FoodImage {
            bytes: vec![1, 2, 3],
            mime: "image/jpeg",
        };
        let body = request_body(&image);
        let inline = &body["contents"][0]["parts"][0]["inline_data"];
        assert_eq!(inline["mime_type"], "image/jpeg");
        assert_eq!(inline["data"], "AQID");
        assert_eq!(
            body["generationConfig"]["responseMimeType"],
            "application/json"
        );
        assert_eq!(
            body["generationConfig"]["responseSchema"]["required"],
            json!(["recognized", "foods"])
        );
    }

    #[test]
    fn respuesta_con_comida_devuelve_cada_alimento() {
        let foods = parse_response(OK).unwrap();
        assert_eq!(foods.len(), 2);
        assert_eq!(foods[0].name, "Tacos de bistec");
        assert_eq!(foods[0].name_en.as_deref(), Some("beef tacos"));
        assert_eq!(foods[0].grams, Some(240.0));

        let estimate =
            FoodEstimate::from_foods(foods.into_iter().map(IdentifiedFood::from).collect())
                .unwrap();
        assert_eq!(
            estimate.totals,
            Nutrients {
                calories_kcal: 650.0,
                protein_g: 38.5,
                fat_g: 27.0
            }
        );
    }

    #[test]
    fn sin_comida_no_se_reconoce() {
        assert_eq!(
            parse_response(NO_FOOD),
            Err(RecognitionError::NotRecognized)
        );
    }

    #[test]
    fn peticion_bloqueada_es_falla_del_servicio() {
        let body = r#"{"promptFeedback":{"blockReason":"SAFETY"}}"#;
        assert!(matches!(
            parse_response(body),
            Err(RecognitionError::Provider(_))
        ));
    }

    #[test]
    fn texto_fuera_del_esquema_es_falla_del_servicio() {
        let body = r#"{"candidates":[{"content":{"parts":[{"text":"no es json"}]},"finishReason":"STOP"}]}"#;
        assert!(matches!(
            parse_response(body),
            Err(RecognitionError::Provider(_))
        ));
        assert!(matches!(
            parse_response("<html>"),
            Err(RecognitionError::Provider(_))
        ));
    }
}
