//! Proveedor híbrido Gemini + FatSecret.
//!
//! El plan gratuito (Basic) de FatSecret **no** reconoce imágenes, así que:
//! 1. Gemini identifica los alimentos y sus gramos (ver `gemini.rs`).
//! 2. FatSecret da los valores de cada alimento: `foods.search` por el nombre en inglés y se toma el primer resultado
//!    cuya descripción venga por gramos (`Per 100g - Calories: 52kcal | Fat: 0.17g | Carbs: 13.81g | Protein: 0.26g`),
//!    escalado a los gramos estimados.
//! 3. Si FatSecret no encuentra el alimento, se conservan los valores de Gemini para ese alimento.
//!
//! Autenticación OAuth 2.0 *client credentials* (`FATSECRET_CLIENT_ID` / `FATSECRET_CLIENT_SECRET`, alcance `basic`);
//! el token se guarda en memoria hasta un minuto antes de que expire.
//! FatSecret exige registrar la IP pública del servidor en su consola y mostrar su atribución en la app.

use std::time::{Duration, Instant};

use async_trait::async_trait;
use serde_json::Value;
use tokio::sync::Mutex;

use super::gemini::{Gemini, GeminiFood};
use super::{
    FoodEstimate, FoodImage, FoodRecognizer, IdentifiedFood, Nutrients, RecognitionError,
    http_client, snippet,
};
use crate::config::Secret;

const TOKEN_URL: &str = "https://oauth.fatsecret.com/connect/token";
const API_URL: &str = "https://platform.fatsecret.com/rest/server.api";
const SEARCH_RESULTS: &str = "10";

pub struct GeminiFatSecret {
    gemini: Gemini,
    client: reqwest::Client,
    client_id: Secret,
    client_secret: Secret,
    token: Mutex<Option<(String, Instant)>>,
}

impl GeminiFatSecret {
    pub fn new(gemini: Gemini, client_id: Secret, client_secret: Secret) -> Self {
        Self {
            gemini,
            client: http_client(),
            client_id,
            client_secret,
            token: Mutex::new(None),
        }
    }

    async fn access_token(&self) -> Result<String, RecognitionError> {
        let mut cached = self.token.lock().await;
        if let Some((token, expires_at)) = cached.as_ref()
            && Instant::now() < *expires_at
        {
            return Ok(token.clone());
        }
        let response = self
            .client
            .post(TOKEN_URL)
            .basic_auth(self.client_id.expose(), Some(self.client_secret.expose()))
            .form(&[("grant_type", "client_credentials"), ("scope", "basic")])
            .send()
            .await
            .map_err(|err| {
                RecognitionError::provider(format!("fatsecret (token): {}", err.without_url()))
            })?;
        let status = response.status();
        let body = response.text().await.map_err(|err| {
            RecognitionError::provider(format!("fatsecret (token): {}", err.without_url()))
        })?;
        if !status.is_success() {
            // El cuerpo de error de OAuth no incluye el secreto.
            return Err(RecognitionError::provider(format!(
                "fatsecret (token): HTTP {status}: {}",
                snippet(&body)
            )));
        }
        let value: Value = serde_json::from_str(&body).map_err(|err| {
            RecognitionError::provider(format!("fatsecret (token): JSON inválido: {err}"))
        })?;
        let token = value["access_token"]
            .as_str()
            .ok_or_else(|| RecognitionError::provider("fatsecret (token): falta access_token"))?
            .to_string();
        let lifetime = value["expires_in"].as_u64().unwrap_or(3600);
        let expires_at = Instant::now() + Duration::from_secs(lifetime.saturating_sub(60));
        *cached = Some((token.clone(), expires_at));
        Ok(token)
    }

    /// Valores por gramo del primer resultado de la búsqueda que venga por gramos.
    async fn per_gram(&self, query: &str) -> Result<Option<Nutrients>, RecognitionError> {
        let token = self.access_token().await?;
        let response = self
            .client
            .get(API_URL)
            .bearer_auth(token)
            .query(&[
                ("method", "foods.search"),
                ("search_expression", query),
                ("max_results", SEARCH_RESULTS),
                ("format", "json"),
            ])
            .send()
            .await
            .map_err(|err| {
                RecognitionError::provider(format!("fatsecret (búsqueda): {}", err.without_url()))
            })?;
        let status = response.status();
        let body = response.text().await.map_err(|err| {
            RecognitionError::provider(format!("fatsecret (búsqueda): {}", err.without_url()))
        })?;
        if !status.is_success() {
            return Err(RecognitionError::provider(format!(
                "fatsecret (búsqueda): HTTP {status}: {}",
                snippet(&body)
            )));
        }
        parse_search(&body)
    }
}

#[async_trait]
impl FoodRecognizer for GeminiFatSecret {
    fn name(&self) -> &'static str {
        "gemini_fatsecret"
    }

    async fn recognize(&self, image: &FoodImage) -> Result<FoodEstimate, RecognitionError> {
        let foods = self.gemini.identify(image).await?;
        let mut identified = Vec::with_capacity(foods.len());
        for food in foods {
            identified.push(self.with_fatsecret_values(food).await?);
        }
        FoodEstimate::from_foods(identified)
    }
}

impl GeminiFatSecret {
    async fn with_fatsecret_values(
        &self,
        food: GeminiFood,
    ) -> Result<IdentifiedFood, RecognitionError> {
        let query = food
            .name_en
            .clone()
            .filter(|n| !n.trim().is_empty())
            .unwrap_or_else(|| food.name.clone());
        let grams = food.grams.filter(|g| *g > 0.0);
        match (grams, self.per_gram(&query).await?) {
            (Some(grams), Some(per_gram)) => Ok(IdentifiedFood {
                name: food.name,
                grams: Some(grams),
                nutrients: Nutrients {
                    calories_kcal: per_gram.calories_kcal * grams,
                    protein_g: per_gram.protein_g * grams,
                    fat_g: per_gram.fat_g * grams,
                },
            }),
            // Sin coincidencia por gramos en FatSecret (o sin gramos): se quedan los valores de Gemini.
            _ => Ok(IdentifiedFood::from(food)),
        }
    }
}

/// Interpreta `foods.search`. `food` puede ser un objeto (un resultado) o una lista; sin resultados → `None`.
/// FatSecret responde algunos errores con HTTP 200 y `{ "error": { code, message } }` (p. ej. IP no registrada).
pub fn parse_search(body: &str) -> Result<Option<Nutrients>, RecognitionError> {
    let value: Value = serde_json::from_str(body).map_err(|err| {
        RecognitionError::provider(format!("fatsecret (búsqueda): JSON inválido: {err}"))
    })?;
    if let Some(error) = value.get("error") {
        return Err(RecognitionError::provider(format!(
            "fatsecret: error {}: {}",
            error["code"],
            error["message"].as_str().unwrap_or_default()
        )));
    }
    let foods = match &value["foods"]["food"] {
        Value::Array(list) => list.clone(),
        Value::Object(_) => vec![value["foods"]["food"].clone()],
        _ => return Ok(None),
    };
    Ok(foods
        .iter()
        .filter_map(|food| food["food_description"].as_str())
        .find_map(parse_description))
}

/// `Per 100g - Calories: 52kcal | Fat: 0.17g | Carbs: 13.81g | Protein: 0.26g` → valores **por gramo**.
/// Descripciones por porción (`Per 1 medium - ...`) no se pueden escalar y devuelven `None`.
pub fn parse_description(description: &str) -> Option<Nutrients> {
    let (portion, values) = description.split_once(" - ")?;
    let amount = portion.trim().strip_prefix("Per ")?.strip_suffix('g')?;
    let grams: f64 = amount.trim().parse().ok().filter(|g: &f64| *g > 0.0)?;

    let mut calories = None;
    let mut protein = None;
    let mut fat = None;
    for pair in values.split('|') {
        let (key, raw) = pair.split_once(':')?;
        let number: f64 = raw
            .trim()
            .trim_end_matches("kcal")
            .trim_end_matches('g')
            .trim()
            .parse()
            .ok()?;
        match key.trim() {
            "Calories" => calories = Some(number),
            "Protein" => protein = Some(number),
            "Fat" => fat = Some(number),
            _ => {}
        }
    }
    Some(Nutrients {
        calories_kcal: calories? / grams,
        protein_g: protein? / grams,
        fat_g: fat? / grams,
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    const SEARCH: &str = include_str!("fixtures/fatsecret_search.json");

    fn close(a: f64, b: f64) -> bool {
        (a - b).abs() < 1e-9
    }

    #[test]
    fn la_descripcion_por_100_g_se_convierte_a_valores_por_gramo() {
        let n = parse_description(
            "Per 100g - Calories: 52kcal | Fat: 0.17g | Carbs: 13.81g | Protein: 0.26g",
        )
        .unwrap();
        assert!(close(n.calories_kcal, 0.52));
        assert!(close(n.fat_g, 0.0017));
        assert!(close(n.protein_g, 0.0026));
    }

    #[test]
    fn otras_cantidades_en_gramos_tambien_se_escalan() {
        let n = parse_description(
            "Per 30g - Calories: 120kcal | Fat: 6.00g | Carbs: 15.00g | Protein: 3.00g",
        )
        .unwrap();
        assert!(close(n.calories_kcal, 4.0));
    }

    #[test]
    fn la_descripcion_por_pieza_no_se_puede_escalar() {
        assert_eq!(
            parse_description(
                "Per 1 medium - Calories: 72kcal | Fat: 0.23g | Carbs: 19.06g | Protein: 0.36g"
            ),
            None
        );
        assert_eq!(parse_description("texto libre"), None);
    }

    #[test]
    fn la_busqueda_toma_el_primer_resultado_por_gramos() {
        // El primero viene por pieza; se usa el segundo (por 100 g).
        let n = parse_search(SEARCH).unwrap().unwrap();
        assert!(close(n.calories_kcal, 1.65));
        assert!(close(n.protein_g, 0.31));
        assert!(close(n.fat_g, 0.036));
    }

    #[test]
    fn un_solo_resultado_viene_como_objeto() {
        let body = r#"{"foods":{"food":{"food_description":"Per 100g - Calories: 100kcal | Fat: 1.00g | Carbs: 1.00g | Protein: 10.00g","food_name":"X"},"total_results":"1"}}"#;
        assert!(parse_search(body).unwrap().is_some());
    }

    #[test]
    fn sin_resultados_no_hay_valores() {
        let body = r#"{"foods":{"max_results":"10","page_number":"0","total_results":"0"}}"#;
        assert_eq!(parse_search(body).unwrap(), None);
    }

    #[test]
    fn error_con_estado_200_es_falla_del_servicio() {
        let body = r#"{"error":{"code":21,"message":"Invalid IP address detected: '1.2.3.4'"}}"#;
        assert!(matches!(
            parse_search(body),
            Err(RecognitionError::Provider(_))
        ));
    }
}
