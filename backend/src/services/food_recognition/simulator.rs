//! Simulador del proveedor (HU-07): misma interfaz que los reales, sin red ni credenciales.
//! Es el proveedor por defecto en desarrollo, en las pruebas y en Postman. `FOOD_SIMULATOR_MODE` fuerza cada caso:
//! `ok` (estimación fija), `not_recognized`, `error` (falla del servicio) y `timeout` (no responde).

use std::time::Duration;

use async_trait::async_trait;

use super::{FoodEstimate, FoodImage, FoodRecognizer, IdentifiedFood, Nutrients, RecognitionError};
use crate::config::SimulatorMode;

/// Plato fijo que devuelve el modo `ok`: arroz, pollo y ensalada.
const PLATE: &[(&str, f64, f64, f64, f64)] = &[
    // nombre, gramos, kcal, proteína, grasa
    ("Arroz blanco cocido", 150.0, 195.0, 4.0, 0.4),
    ("Pechuga de pollo a la plancha", 120.0, 198.0, 37.2, 4.3),
    ("Ensalada verde", 80.0, 20.0, 1.0, 0.2),
];

pub struct Simulator {
    mode: SimulatorMode,
}

impl Simulator {
    pub fn new(mode: SimulatorMode) -> Self {
        Self { mode }
    }
}

#[async_trait]
impl FoodRecognizer for Simulator {
    fn name(&self) -> &'static str {
        "simulator"
    }

    async fn recognize(&self, _image: &FoodImage) -> Result<FoodEstimate, RecognitionError> {
        match self.mode {
            SimulatorMode::Ok => FoodEstimate::from_foods(
                PLATE
                    .iter()
                    .map(|(name, grams, kcal, protein, fat)| IdentifiedFood {
                        name: name.to_string(),
                        grams: Some(*grams),
                        nutrients: Nutrients {
                            calories_kcal: *kcal,
                            protein_g: *protein,
                            fat_g: *fat,
                        },
                    })
                    .collect(),
            ),
            SimulatorMode::NotRecognized => Err(RecognitionError::NotRecognized),
            SimulatorMode::Error => Err(RecognitionError::provider(
                "simulador: falla forzada con FOOD_SIMULATOR_MODE=error",
            )),
            SimulatorMode::Timeout => {
                // Más que cualquier tiempo de espera permitido: `FoodService::estimate` corta antes.
                tokio::time::sleep(Duration::from_secs(60)).await;
                Err(RecognitionError::Timeout)
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn el_modo_ok_devuelve_siempre_el_mismo_plato() {
        let image = FoodImage {
            bytes: vec![],
            mime: "image/jpeg",
        };
        let simulator = Simulator::new(SimulatorMode::Ok);
        let first = simulator.recognize(&image).await.unwrap();
        let second = simulator.recognize(&image).await.unwrap();
        assert_eq!(first, second);
        assert_eq!(first.foods.len(), 3);
        assert_eq!(first.foods[0].name, "Arroz blanco cocido");
        assert_eq!(
            first.totals,
            Nutrients {
                calories_kcal: 413.0,
                protein_g: 42.2,
                fat_g: 4.9
            }
        );
    }
}
