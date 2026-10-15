//! HU-07 / TEC-02 — capa del adaptador de reconocimiento de alimentos (RNF-13).
//!
//! Los handlers y los servicios de la API solo conocen [`FoodService`] y el trait [`FoodRecognizer`]: el proveedor
//! (simulador, LogMeal, Gemini o Gemini + FatSecret) se elige con `FOOD_PROVIDER` y cambiarlo no toca rutas ni handlers.
//!
//! Contrato de cada proveedor:
//! - **Entrada:** [`FoodImage`], la foto ya preparada por [`preprocess::prepare`] (JPEG de máximo 1000 px por lado).
//! - **Salida:** [`FoodEstimate`] con los alimentos identificados (nombre, gramos si los da, calorías, proteína y grasa)
//!   y los totales. Una lista vacía nunca es un éxito: es [`RecognitionError::NotRecognized`].
//! - **Errores:** [`RecognitionError`]. El tiempo de espera lo aplica [`FoodService::estimate`] a cualquier proveedor.
//!
//! Este módulo no usa tipos HTTP de Axum: la traducción a códigos de la API está en `services::meal_estimates`.

use std::sync::Arc;
use std::time::Duration;

use async_trait::async_trait;

use crate::config::{FoodConfig, FoodProviderKind};

pub mod fatsecret;
pub mod gemini;
pub mod logmeal;
pub mod preprocess;
pub mod simulator;

/// Foto lista para enviarse al proveedor.
#[derive(Debug, Clone)]
pub struct FoodImage {
    pub bytes: Vec<u8>,
    /// `image/jpeg` o `image/png`.
    pub mime: &'static str,
}

/// Calorías (kcal), proteína (g) y grasa (g).
#[derive(Debug, Clone, Copy, Default, PartialEq)]
pub struct Nutrients {
    pub calories_kcal: f64,
    pub protein_g: f64,
    pub fat_g: f64,
}

impl Nutrients {
    fn add(self, other: Nutrients) -> Nutrients {
        Nutrients {
            calories_kcal: self.calories_kcal + other.calories_kcal,
            protein_g: self.protein_g + other.protein_g,
            fat_g: self.fat_g + other.fat_g,
        }
    }

    /// Redondea a un decimal y convierte negativos o valores no finitos en 0.
    pub fn rounded(self) -> Nutrients {
        Nutrients {
            calories_kcal: round1(self.calories_kcal),
            protein_g: round1(self.protein_g),
            fat_g: round1(self.fat_g),
        }
    }
}

/// Redondea a un decimal; negativos y valores no finitos quedan en 0.
pub fn round1(value: f64) -> f64 {
    if value.is_finite() && value > 0.0 {
        (value * 10.0).round() / 10.0
    } else {
        0.0
    }
}

/// Un alimento identificado en la foto (RF-06).
#[derive(Debug, Clone, PartialEq)]
pub struct IdentifiedFood {
    pub name: String,
    /// Peso estimado de la porción, si el proveedor lo da.
    pub grams: Option<f64>,
    pub nutrients: Nutrients,
}

/// Resultado de un proveedor: alimentos identificados y totales (suma de los alimentos).
#[derive(Debug, Clone, PartialEq)]
pub struct FoodEstimate {
    pub foods: Vec<IdentifiedFood>,
    pub totals: Nutrients,
}

impl FoodEstimate {
    /// Arma la estimación con los totales calculados y todo redondeado a un decimal.
    /// Sin alimentos, la foto no se reconoció.
    pub fn from_foods(foods: Vec<IdentifiedFood>) -> Result<Self, RecognitionError> {
        let foods: Vec<IdentifiedFood> = foods
            .into_iter()
            .filter(|food| !food.name.trim().is_empty())
            .map(|food| IdentifiedFood {
                name: food.name.trim().to_string(),
                grams: food.grams.filter(|g| g.is_finite() && *g > 0.0).map(round1),
                nutrients: food.nutrients.rounded(),
            })
            .collect();
        if foods.is_empty() {
            return Err(RecognitionError::NotRecognized);
        }
        let totals = foods
            .iter()
            .fold(Nutrients::default(), |acc, food| acc.add(food.nutrients))
            .rounded();
        Ok(Self { foods, totals })
    }
}

/// Errores de un proveedor.
#[derive(Debug, Clone, PartialEq)]
pub enum RecognitionError {
    /// La foto no muestra comida que el proveedor reconozca (RF-06, CU-01 flujo 4a).
    NotRecognized,
    /// El proveedor falló: error HTTP, respuesta inesperada, cuota agotada o credenciales inválidas.
    /// El texto es para el log; nunca se manda al cliente.
    Provider(String),
    /// El proveedor no respondió dentro del tiempo de espera.
    Timeout,
}

impl RecognitionError {
    pub fn provider(detail: impl std::fmt::Display) -> Self {
        Self::Provider(detail.to_string())
    }
}

/// Interfaz que implementa cada proveedor (y el simulador).
#[async_trait]
pub trait FoodRecognizer: Send + Sync {
    /// Nombre corto del proveedor (logs y banco de pruebas).
    fn name(&self) -> &'static str;

    /// Identifica los alimentos de la foto y estima sus valores.
    async fn recognize(&self, image: &FoodImage) -> Result<FoodEstimate, RecognitionError>;
}

/// Proveedor configurado más el tiempo de espera. Es lo que guarda `AppState`.
#[derive(Clone)]
pub struct FoodService {
    recognizer: Arc<dyn FoodRecognizer>,
    timeout: Duration,
}

impl FoodService {
    pub fn new(recognizer: Arc<dyn FoodRecognizer>, timeout: Duration) -> Self {
        Self {
            recognizer,
            timeout,
        }
    }

    /// Servicio con el simulador (pruebas).
    pub fn simulator(mode: crate::config::SimulatorMode, timeout: Duration) -> Self {
        Self::new(Arc::new(simulator::Simulator::new(mode)), timeout)
    }

    /// Construye el proveedor que indica la configuración.
    pub fn from_config(config: &FoodConfig) -> Self {
        Self::new(build_recognizer(config), config.timeout)
    }

    pub fn provider_name(&self) -> &'static str {
        self.recognizer.name()
    }

    /// Llama al proveedor con el tiempo de espera configurado (máximo 10 s, RNF-01).
    pub async fn estimate(&self, image: &FoodImage) -> Result<FoodEstimate, RecognitionError> {
        match tokio::time::timeout(self.timeout, self.recognizer.recognize(image)).await {
            Ok(result) => result,
            Err(_) => Err(RecognitionError::Timeout),
        }
    }
}

/// Instancia el proveedor elegido. `FoodConfig::from_vars` ya garantizó que sus credenciales existen.
pub fn build_recognizer(config: &FoodConfig) -> Arc<dyn FoodRecognizer> {
    match config.provider {
        FoodProviderKind::Simulator => Arc::new(simulator::Simulator::new(config.simulator_mode)),
        FoodProviderKind::LogMeal => Arc::new(logmeal::LogMeal::new(
            config
                .logmeal_token
                .clone()
                .expect("LOGMEAL_API_TOKEN validado en la configuración"),
        )),
        FoodProviderKind::Gemini => Arc::new(gemini::Gemini::new(
            config
                .gemini_api_key
                .clone()
                .expect("GEMINI_API_KEY validado en la configuración"),
            config.gemini_model.clone(),
        )),
        FoodProviderKind::GeminiFatSecret => Arc::new(fatsecret::GeminiFatSecret::new(
            gemini::Gemini::new(
                config
                    .gemini_api_key
                    .clone()
                    .expect("GEMINI_API_KEY validado en la configuración"),
                config.gemini_model.clone(),
            ),
            config
                .fatsecret_client_id
                .clone()
                .expect("FATSECRET_CLIENT_ID validado en la configuración"),
            config
                .fatsecret_client_secret
                .clone()
                .expect("FATSECRET_CLIENT_SECRET validado en la configuración"),
        )),
    }
}

/// Cliente HTTP compartido por los proveedores reales. El tiempo total lo controla [`FoodService::estimate`];
/// aquí solo se acota la conexión.
pub(crate) fn http_client() -> reqwest::Client {
    reqwest::Client::builder()
        .connect_timeout(Duration::from_secs(5))
        .user_agent("MacroFit-backend")
        .build()
        .expect("el cliente HTTP se construye con opciones fijas")
}

/// Recorta el cuerpo de una respuesta de error para el log.
pub(crate) fn snippet(body: &str) -> String {
    let trimmed: String = body.chars().take(300).collect();
    trimmed.replace('\n', " ")
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::config::SimulatorMode;

    fn food(name: &str, kcal: f64, protein: f64, fat: f64) -> IdentifiedFood {
        IdentifiedFood {
            name: name.to_string(),
            grams: Some(100.0),
            nutrients: Nutrients {
                calories_kcal: kcal,
                protein_g: protein,
                fat_g: fat,
            },
        }
    }

    fn image() -> FoodImage {
        FoodImage {
            bytes: vec![0xFF, 0xD8, 0xFF],
            mime: "image/jpeg",
        }
    }

    fn service(mode: SimulatorMode, timeout: Duration) -> FoodService {
        FoodService::new(Arc::new(simulator::Simulator::new(mode)), timeout)
    }

    #[test]
    fn los_totales_son_la_suma_redondeada_de_los_alimentos() {
        let estimate = FoodEstimate::from_foods(vec![
            food("Arroz", 130.04, 2.66, 0.28),
            food("Pollo", 165.0, 31.0, 3.6),
        ])
        .unwrap();
        assert_eq!(estimate.foods.len(), 2);
        assert_eq!(
            estimate.totals,
            Nutrients {
                calories_kcal: 295.0,
                protein_g: 33.7,
                fat_g: 3.9
            }
        );
    }

    #[test]
    fn sin_alimentos_no_se_reconocio_la_foto() {
        assert_eq!(
            FoodEstimate::from_foods(vec![]),
            Err(RecognitionError::NotRecognized)
        );
        assert_eq!(
            FoodEstimate::from_foods(vec![food("  ", 10.0, 1.0, 1.0)]),
            Err(RecognitionError::NotRecognized)
        );
    }

    #[test]
    fn valores_negativos_o_invalidos_quedan_en_cero() {
        let estimate =
            FoodEstimate::from_foods(vec![food("Agua", -5.0, f64::NAN, f64::INFINITY)]).unwrap();
        assert_eq!(estimate.totals, Nutrients::default());
    }

    #[tokio::test]
    async fn exito_con_el_simulador() {
        let estimate = service(SimulatorMode::Ok, Duration::from_secs(10))
            .estimate(&image())
            .await
            .unwrap();
        assert!(!estimate.foods.is_empty());
        assert!(estimate.totals.calories_kcal > 0.0);
    }

    #[tokio::test]
    async fn comida_no_reconocida_con_el_simulador() {
        let result = service(SimulatorMode::NotRecognized, Duration::from_secs(10))
            .estimate(&image())
            .await;
        assert_eq!(result, Err(RecognitionError::NotRecognized));
    }

    #[tokio::test]
    async fn falla_del_servicio_con_el_simulador() {
        let result = service(SimulatorMode::Error, Duration::from_secs(10))
            .estimate(&image())
            .await;
        assert!(matches!(result, Err(RecognitionError::Provider(_))));
    }

    #[tokio::test]
    async fn el_servicio_corta_al_vencer_el_tiempo_de_espera() {
        let started = std::time::Instant::now();
        let result = service(SimulatorMode::Timeout, Duration::from_millis(50))
            .estimate(&image())
            .await;
        assert_eq!(result, Err(RecognitionError::Timeout));
        assert!(started.elapsed() < Duration::from_secs(2));
    }
}
