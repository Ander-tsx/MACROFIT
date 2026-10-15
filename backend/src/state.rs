use mongodb::Database;

use crate::config::TokenConfig;
use crate::services::food_recognition::FoodService;

/// Estado compartido por todos los handlers.
#[derive(Clone)]
pub struct AppState {
    pub db: Database,
    pub tokens: TokenConfig,
    /// Proveedor de reconocimiento de alimentos (HU-07), elegido con `FOOD_PROVIDER`.
    pub food: FoodService,
}
